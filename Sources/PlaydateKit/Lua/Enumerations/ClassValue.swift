extension Lua {
    /// A class constant for `Lua.registerClass`. Wraps `lua_val`.
    public enum ClassValue {
        case int(name: String, value: UInt32)
        case float(name: String, value: Float)
        case string(name: String, value: String)
    }
}
