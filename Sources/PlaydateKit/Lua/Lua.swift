internal import CPlaydate

/// The cached `playdate->lua` C API table.
var luaAPI: UnsafePointer<playdate_lua> { Playdate.luaAPI.unsafelyUnwrapped }

/// The Lua bridge: registering C functions and classes, and exchanging
/// values with Lua code.
///
/// Lua callbacks are C function pointers without userdata, so functions
/// registered here must be `@convention(c)` (the `CFunction` typealias),
/// not capturing closures.
public enum Lua {}

extension Lua {
    /// Buffers passed to `registerClass`/`addFunction`; the OS may keep
    /// referencing them, so they are retained for the life of the game.
    nonisolated(unsafe) private static var retainedBuffers: [UnsafeMutableRawPointer] = []

    private static func retainedCString(_ string: String) -> UnsafePointer<CChar> {
        let copy = string.copiedPlaydateCString()
        retainedBuffers.append(UnsafeMutableRawPointer(copy))
        return UnsafePointer(copy)
    }

    // MARK: - Registration

    /// Makes `function` callable from Lua as `name` (which may contain dots
    /// for namespacing, e.g. "mylib.myfunc").
    public static func addFunction(_ function: CFunction, name: String) throws(PlaydateError) {
        var error: UnsafePointer<CChar>?
        let ok = name.withPlaydateCString {
            luaAPI.pointee.addFunction.unsafelyUnwrapped(function, $0, &error) != 0
        }
        if !ok { throw PlaydateError(cString: error) }
    }

    /// Registers a Lua class named `name` with the given methods and
    /// constants. When `isStatic` is `true` a plain table of functions is
    /// created instead of a class.
    public static func registerClass(name: String,
                                     functions: [(name: String, function: CFunction)],
                                     values: [ClassValue] = [],
                                     isStatic: Bool = false) throws(PlaydateError) {
        // The registration tables are kept alive permanently: the OS
        // documents no copying guarantees for them.
        var registrations: [lua_reg] = functions.map { entry in
            lua_reg(name: retainedCString(entry.name), func: entry.function)
        }
        registrations.append(lua_reg(name: nil, func: nil))

        var constants: [lua_val] = values.map { value in
            switch value {
            case .int(let name, let intValue):
                return lua_val(name: retainedCString(name), type: kInt, v: .init(intval: intValue))
            case .float(let name, let floatValue):
                return lua_val(name: retainedCString(name), type: kFloat, v: .init(floatval: floatValue))
            case .string(let name, let stringValue):
                return lua_val(name: retainedCString(name), type: kStr,
                               v: .init(strval: retainedCString(stringValue)))
            }
        }
        constants.append(lua_val(name: nil, type: kInt, v: .init(intval: 0)))

        let registrationsBuffer = UnsafeMutablePointer<lua_reg>.allocate(capacity: registrations.count)
        registrationsBuffer.initialize(from: registrations, count: registrations.count)
        retainedBuffers.append(UnsafeMutableRawPointer(registrationsBuffer))

        let constantsBuffer = UnsafeMutablePointer<lua_val>.allocate(capacity: constants.count)
        constantsBuffer.initialize(from: constants, count: constants.count)
        retainedBuffers.append(UnsafeMutableRawPointer(constantsBuffer))

        var error: UnsafePointer<CChar>?
        let ok = name.withPlaydateCString {
            luaAPI.pointee.registerClass.unsafelyUnwrapped($0, registrationsBuffer,
                                                   values.isEmpty ? nil : constantsBuffer,
                                                   isStatic ? 1 : 0, &error) != 0
        }
        if !ok { throw PlaydateError(cString: error) }
    }

    /// Pushes a function onto the stack, e.g. for `setUserValue`.
    public static func pushFunction(_ function: CFunction) {
        luaAPI.pointee.pushFunction.unsafelyUnwrapped(function)
    }

    /// From a class's `__index` callback: looks up the key in the instance
    /// metatable first. Returns 1 if a value was found.
    public static func indexMetatable() -> Bool {
        luaAPI.pointee.indexMetatable.unsafelyUnwrapped() != 0
    }

    /// Pauses the Lua runtime.
    public static func stop() {
        luaAPI.pointee.stop.unsafelyUnwrapped()
    }

    /// Resumes the Lua runtime.
    public static func start() {
        luaAPI.pointee.start.unsafelyUnwrapped()
    }

    // MARK: - Arguments

    /// The number of arguments the Lua caller passed. Positions are 1-based.
    public static var argumentCount: Int {
        Int(luaAPI.pointee.getArgCount.unsafelyUnwrapped())
    }

    /// The type of the argument at 1-based `position`; for objects, also the
    /// class name.
    public static func argumentType(at position: Int) -> (kind: Kind, className: String?) {
        var className: UnsafePointer<CChar>?
        let type = luaAPI.pointee.getArgType.unsafelyUnwrapped(Int32(position), &className)
        return (Kind(type), String(playdateCString: className))
    }

    public static func argumentIsNil(at position: Int) -> Bool {
        luaAPI.pointee.argIsNil.unsafelyUnwrapped(Int32(position)) != 0
    }

    public static func boolArgument(at position: Int) -> Bool {
        luaAPI.pointee.getArgBool.unsafelyUnwrapped(Int32(position)) != 0
    }

    public static func intArgument(at position: Int) -> Int {
        Int(luaAPI.pointee.getArgInt.unsafelyUnwrapped(Int32(position)))
    }

    public static func floatArgument(at position: Int) -> Float {
        luaAPI.pointee.getArgFloat.unsafelyUnwrapped(Int32(position))
    }

    public static func stringArgument(at position: Int) -> String? {
        String(playdateCString: luaAPI.pointee.getArgString.unsafelyUnwrapped(Int32(position)))
    }

    /// The argument as raw bytes (which may contain embedded zeros).
    public static func bytesArgument(at position: Int) -> [UInt8]? {
        var length = 0
        guard let bytes = luaAPI.pointee.getArgBytes.unsafelyUnwrapped(Int32(position), &length) else {
            return nil
        }
        let buffer = UnsafeRawBufferPointer(start: bytes, count: length)
        return [UInt8](buffer)
    }

    /// The argument as an object instance of class `type`, with the
    /// `UDObject` handle for retaining it.
    public static func objectArgument(at position: Int, type: String)
        -> (object: UnsafeMutableRawPointer?, userdataObject: UDObject?) {
        var userdataObject: OpaquePointer?
        // The C API takes a non-const class name but only reads it, so the
        // stack copy can be passed with a mutating cast.
        let object = type.withPlaydateCString { cType in
            luaAPI.pointee.getArgObject.unsafelyUnwrapped(
                Int32(position), UnsafeMutablePointer(mutating: cType), &userdataObject)
        }
        return (object, userdataObject.map { UDObject(pointer: $0) })
    }

    /// The argument as a bitmap. References an object owned by Lua; retain
    /// the Lua value while using it.
    public static func bitmapArgument(at position: Int) -> Graphics.Bitmap? {
        guard let bitmap = luaAPI.pointee.getBitmap.unsafelyUnwrapped(Int32(position)) else { return nil }
        return Graphics.Bitmap(pointer: bitmap, isOwned: false)
    }

    /// The argument as a sprite.
    public static func spriteArgument(at position: Int) -> Sprite? {
        guard let sprite = luaAPI.pointee.getSprite.unsafelyUnwrapped(Int32(position)) else { return nil }
        return Sprite.wrapper(for: sprite)
    }

    // MARK: - Return values

    /// Pushes nil onto the stack.
    public static func pushNil() {
        luaAPI.pointee.pushNil.unsafelyUnwrapped()
    }

    /// Pushes a boolean onto the stack.
    public static func push(_ value: Bool) {
        luaAPI.pointee.pushBool.unsafelyUnwrapped(value ? 1 : 0)
    }

    /// Pushes an integer onto the stack.
    public static func push(_ value: Int) {
        luaAPI.pointee.pushInt.unsafelyUnwrapped(Int32(value))
    }

    /// Pushes a float onto the stack.
    public static func push(_ value: Float) {
        luaAPI.pointee.pushFloat.unsafelyUnwrapped(value)
    }

    /// Pushes a string onto the stack.
    public static func push(_ value: String) {
        value.withPlaydateCString { luaAPI.pointee.pushString.unsafelyUnwrapped($0) }
    }

    /// Pushes raw bytes (which may contain embedded zeros) onto the stack
    /// as a Lua string.
    public static func push(bytes: [UInt8]) {
        bytes.withUnsafeBytes { buffer in
            luaAPI.pointee.pushBytes.unsafelyUnwrapped(
                buffer.baseAddress?.assumingMemoryBound(to: CChar.self), buffer.count)
        }
    }

    /// Pushes a bitmap onto the stack.
    public static func push(_ bitmap: Graphics.Bitmap) {
        luaAPI.pointee.pushBitmap.unsafelyUnwrapped(bitmap.pointer)
    }

    /// Pushes a sprite onto the stack.
    public static func push(_ sprite: Sprite) {
        luaAPI.pointee.pushSprite.unsafelyUnwrapped(sprite.pointer)
    }

    /// Wraps `object` in a Lua instance of class `type` and pushes it, with
    /// `valueCount` extra user-value slots.
    @discardableResult
    public static func pushObject(_ object: UnsafeMutableRawPointer, type: String,
                                  valueCount: Int = 0) -> UDObject? {
        // The C API takes a non-const class name but only reads it, so the
        // stack copy can be passed with a mutating cast.
        let pointer = type.withPlaydateCString { cType in
            luaAPI.pointee.pushObject.unsafelyUnwrapped(
                object, UnsafeMutablePointer(mutating: cType), Int32(valueCount))
        }
        guard let pointer else { return nil }
        return UDObject(pointer: pointer)
    }

    // MARK: - Calling Lua

    /// Calls the Lua function `name`. Push the arguments onto the stack
    /// first. Calling Lua from Swift has overhead; use sparingly.
    public static func callFunction(_ name: String, argumentCount: Int = 0) throws(PlaydateError) {
        var error: UnsafePointer<CChar>?
        let ok = name.withPlaydateCString {
            luaAPI.pointee.callFunction.unsafelyUnwrapped($0, Int32(argumentCount), &error) != 0
        }
        if !ok { throw PlaydateError(cString: error) }
    }
}
