extension JSON {
    /// A JSON value tree, produced by `JSON.decode` and consumed by `JSON.encode(_:pretty:)`.
    public indirect enum Value {
        case null
        case bool(Bool)
        /// Encoded as 32-bit; must fit in `Int32`.
        case int(Int)
        /// A number with a fractional part.
        case float(Float)
        case string(String)
        case array([Value])
        /// A JSON object; key order is not preserved.
        case table([String: Value])
    }
}
