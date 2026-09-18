// Internal suffices: `CFunction.swift` publicly imports `lua_CFunction`.
internal import CPlaydate

/// The cached `playdate->lua` C API table.
var luaAPI: UnsafePointer<playdate_lua> { Playdate.luaAPI.unsafelyUnwrapped }

/// Lua bridge: registers C functions and classes; exchanges values via the Lua stack.
/// Registered functions must be `CFunction`s (`@convention(c)`), not capturing
/// closures. Argument positions are 1-based.
public enum Lua {}

extension Lua {
    /// Strings and tables passed to `registerClass`; never freed (the OS may keep them).
    nonisolated(unsafe) private static var retainedBuffers: [UnsafeMutableRawPointer] = []

    private static func retainedCString(_ string: String) -> UnsafePointer<CChar> {
        let copy = string.copiedPlaydateCString()
        retainedBuffers.append(UnsafeMutableRawPointer(copy))
        return UnsafePointer(copy)
    }

    // MARK: - Registration

    /// Makes `function` callable from Lua as `name`, which may be a dotted path
    /// ("mylib.myfunc"). Throws `PlaydateError`.
    public static func addFunction(_ function: CFunction, name: String) throws(PlaydateError) {
        var error: UnsafePointer<CChar>?
        let ok = name.withCString {
            luaAPI.pointee.addFunction.unsafelyUnwrapped(function, $0, &error) != 0
        }
        if !ok { throw PlaydateError(cString: error) }
    }

    /// Registers class `name` (a metatable; a plain table if `isStatic`) with
    /// `functions` and constant `values`. Throws `PlaydateError`.
    public static func registerClass(name: String,
                                     functions: [(name: String, function: CFunction)],
                                     values: [ClassValue] = [],
                                     isStatic: Bool = false) throws(PlaydateError) {
        // Leaked on purpose: the C API is not documented to copy them.
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
        let ok = name.withCString {
            luaAPI.pointee.registerClass.unsafelyUnwrapped($0, registrationsBuffer,
                                                   values.isEmpty ? nil : constantsBuffer,
                                                   isStatic ? 1 : 0, &error) != 0
        }
        if !ok { throw PlaydateError(cString: error) }
    }

    public static func pushFunction(_ function: CFunction) {
        luaAPI.pointee.pushFunction.unsafelyUnwrapped(function)
    }

    /// Looks up the indexed key in the class metatable; call first in `__index`.
    /// If `true`, the value is on the stack and `__index` should return 1.
    public static func indexMetatable() -> Bool {
        luaAPI.pointee.indexMetatable.unsafelyUnwrapped() != 0
    }

    /// Stops the Lua run loop.
    public static func stop() {
        luaAPI.pointee.stop.unsafelyUnwrapped()
    }

    /// Restarts the Lua run loop after `stop()`.
    public static func start() {
        luaAPI.pointee.start.unsafelyUnwrapped()
    }

    // MARK: - Arguments

    /// The number of arguments to the current Lua call.
    public static var argumentCount: Int {
        Int(luaAPI.pointee.getArgCount.unsafelyUnwrapped())
    }

    /// The argument's type, plus its metatable name if `.object` (else `nil`).
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

    /// `nil` if the C API returns `NULL`.
    public static func stringArgument(at position: Int) -> String? {
        String(playdateCString: luaAPI.pointee.getArgString.unsafelyUnwrapped(Int32(position)))
    }

    /// Raw bytes (may contain zeros), or `nil` if the C API returns `NULL`.
    public static func bytesArgument(at position: Int) -> [UInt8]? {
        var length = 0
        guard let bytes = luaAPI.pointee.getArgBytes.unsafelyUnwrapped(Int32(position), &length) else {
            return nil
        }
        let buffer = UnsafeRawBufferPointer(start: bytes, count: length)
        return [UInt8](buffer)
    }

    /// Instance of class `type` and its handle; `object` is `nil` on type mismatch.
    public static func objectArgument(at position: Int, type: String)
        -> (object: UnsafeMutableRawPointer?, userdataObject: UDObject?) {
        var userdataObject: OpaquePointer?
        // The C API declares the class name non-const but only reads it.
        let object = type.withCString { cType in
            luaAPI.pointee.getArgObject.unsafelyUnwrapped(
                Int32(position), UnsafeMutablePointer(mutating: cType), &userdataObject)
        }
        return (object, userdataObject.map { UDObject(pointer: $0) })
    }

    /// Lua owns the bitmap; keep the Lua value alive while using it.
    public static func bitmapArgument(at position: Int) -> Graphics.Bitmap? {
        guard let bitmap = luaAPI.pointee.getBitmap.unsafelyUnwrapped(Int32(position)) else { return nil }
        return Graphics.Bitmap(pointer: bitmap, isOwned: false)
    }

    public static func spriteArgument(at position: Int) -> Sprite? {
        guard let sprite = luaAPI.pointee.getSprite.unsafelyUnwrapped(Int32(position)) else { return nil }
        return Sprite.wrapper(for: sprite)
    }

    // MARK: - Return values

    public static func pushNil() {
        luaAPI.pointee.pushNil.unsafelyUnwrapped()
    }

    public static func push(_ value: Bool) {
        luaAPI.pointee.pushBool.unsafelyUnwrapped(value ? 1 : 0)
    }

    public static func push(_ value: Int) {
        luaAPI.pointee.pushInt.unsafelyUnwrapped(Int32(value))
    }

    public static func push(_ value: Float) {
        luaAPI.pointee.pushFloat.unsafelyUnwrapped(value)
    }

    public static func push(_ value: String) {
        value.withCString { luaAPI.pointee.pushString.unsafelyUnwrapped($0) }
    }

    /// Pushes `bytes` as a Lua string; zeros are kept.
    public static func push(bytes: [UInt8]) {
        bytes.withUnsafeBytes { buffer in
            luaAPI.pointee.pushBytes.unsafelyUnwrapped(
                buffer.baseAddress?.assumingMemoryBound(to: CChar.self), buffer.count)
        }
    }

    public static func push(_ bitmap: Graphics.Bitmap) {
        luaAPI.pointee.pushBitmap.unsafelyUnwrapped(bitmap.pointer)
    }

    public static func push(_ sprite: Sprite) {
        luaAPI.pointee.pushSprite.unsafelyUnwrapped(sprite.pointer)
    }

    /// Pushes `object` as an instance of class `type` with `valueCount` user-value
    /// slots. Returns its handle, or `nil` on failure.
    @discardableResult
    public static func pushObject(_ object: UnsafeMutableRawPointer, type: String,
                                  valueCount: Int = 0) -> UDObject? {
        // The C API declares the class name non-const but only reads it.
        let pointer = type.withCString { cType in
            luaAPI.pointee.pushObject.unsafelyUnwrapped(
                object, UnsafeMutablePointer(mutating: cType), Int32(valueCount))
        }
        guard let pointer else { return nil }
        return UDObject(pointer: pointer)
    }

    // MARK: - Calling Lua

    /// Calls Lua function `name` (dotted path allowed) with the `argumentCount`
    /// arguments already pushed. Slow; use sparingly. Throws `PlaydateError`.
    public static func callFunction(_ name: String, argumentCount: Int = 0) throws(PlaydateError) {
        var error: UnsafePointer<CChar>?
        let ok = name.withCString {
            luaAPI.pointee.callFunction.unsafelyUnwrapped($0, Int32(argumentCount), &error) != 0
        }
        if !ok { throw PlaydateError(cString: error) }
    }
}
