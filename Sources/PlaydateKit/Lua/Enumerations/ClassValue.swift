extension Lua {
    /// A constant published on a registered class.
    public enum ClassValue {
        case int(name: String, value: UInt32)
        case float(name: String, value: Float)
        case string(name: String, value: String)
    }
}
