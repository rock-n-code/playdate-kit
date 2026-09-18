internal import CPlaydate

extension Lua {
    /// The type of a value on the Lua stack. Wraps `LuaType`.
    public enum Kind: UInt32, Sendable {
        /// Also used for unrecognized type codes.
        case `nil` = 0
        case bool = 1
        case int = 2
        case float = 3
        case string = 4
        case table = 5
        case function = 6
        /// A coroutine.
        case thread = 7
        /// Userdata.
        case object = 8

        init(_ type: LuaType) { self = Kind(rawValue: UInt32(type.rawValue)) ?? .nil }
    }
}
