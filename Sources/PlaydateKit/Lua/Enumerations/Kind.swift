internal import CPlaydate

extension Lua {
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
}
