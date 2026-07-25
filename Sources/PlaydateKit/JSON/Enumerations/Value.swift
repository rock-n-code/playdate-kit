extension JSON {
    /// A decoded JSON value.
    public indirect enum Value {
        /// A JSON `null`.
        case null
        /// A JSON `true` or `false`.
        case bool(Bool)
        /// A JSON number without a fractional part.
        case int(Int)
        /// A JSON number with a fractional part.
        case float(Float)
        /// A JSON string.
        case string(String)
        /// A JSON array.
        case array([Value])
        /// A JSON object.
        case table([String: Value])
    }
}
