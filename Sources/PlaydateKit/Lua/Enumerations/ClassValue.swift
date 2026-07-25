extension Lua {
    /// A constant published on a registered class.
    public enum ClassValue {
        /// An integer constant.
        case int(name: String, value: UInt32)
        /// A floating-point constant.
        case float(name: String, value: Float)
        /// A string constant.
        case string(name: String, value: String)
    }
}
