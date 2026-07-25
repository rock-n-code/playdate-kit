//
//  Lua.swift
//  Wraps `playdate->lua` (pd_api_lua.h).
//
//  Lua callbacks are C function pointers without userdata, so functions
//  registered here must be `@convention(c)` (the `CFunction` typealias), not
//  capturing closures.
//

public import CPlaydate

private var luaAPI: UnsafePointer<playdate_lua> { Playdate.luaAPI }

/// The Lua bridge: registering C functions and classes, and exchanging
/// values with Lua code.
public enum Lua {}

extension Lua {
    /// A function callable from Lua. Returns the number of values it pushed
    /// onto the stack.
    public typealias CFunction = lua_CFunction

    /// The type of a value on the Lua stack.
    public enum Kind: UInt32, Sendable {
        case `nil` = 0
        case bool = 1
        case int = 2
        case float = 3
        case string = 4
        case table = 5
        case function = 6
        case thread = 7
        case object = 8

        init(_ type: LuaType) { self = Kind(rawValue: UInt32(type.rawValue)) ?? .nil }
    }

    /// A constant published on a registered class.
    public enum ClassValue {
        case int(name: String, value: UInt32)
        case float(name: String, value: Float)
        case string(name: String, value: String)
    }

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
        let cType = type.copiedPlaydateCString()
        defer { cType.deallocate() }
        var userdataObject: OpaquePointer?
        let object = luaAPI.pointee.getArgObject.unsafelyUnwrapped(Int32(position), cType, &userdataObject)
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
        value.withPlaydateCString { luaAPI.pointee.pushString.unsafelyUnwrapped($0) }
    }

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

    /// Wraps `object` in a Lua instance of class `type` and pushes it, with
    /// `valueCount` extra user-value slots.
    @discardableResult
    public static func pushObject(_ object: UnsafeMutableRawPointer, type: String,
                                  valueCount: Int = 0) -> UDObject? {
        let cType = type.copiedPlaydateCString()
        defer { cType.deallocate() }
        guard let pointer = luaAPI.pointee.pushObject.unsafelyUnwrapped(object, cType, Int32(valueCount)) else {
            return nil
        }
        return UDObject(pointer: pointer)
    }

    /// A handle to a Lua-owned object. Wraps `LuaUDObject`.
    public struct UDObject {
        let pointer: OpaquePointer

        /// Prevents the object from being garbage-collected until `release()`.
        @discardableResult
        public func retain() -> UDObject {
            UDObject(pointer: luaAPI.pointee.retainObject.unsafelyUnwrapped(pointer).unsafelyUnwrapped)
        }

        public func release() {
            luaAPI.pointee.releaseObject.unsafelyUnwrapped(pointer)
        }

        /// Pops the value on top of the stack and stores it in the object's
        /// user-value `slot` (1-based).
        public func setUserValue(slot: UInt32) {
            luaAPI.pointee.setUserValue.unsafelyUnwrapped(pointer, slot)
        }

        /// Pushes the value in user-value `slot` onto the stack and returns
        /// its stack position, or `nil` if there is none.
        @discardableResult
        public func getUserValue(slot: UInt32) -> Int? {
            let position = luaAPI.pointee.getUserValue.unsafelyUnwrapped(pointer, slot)
            return position == 0 ? nil : Int(position)
        }
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
