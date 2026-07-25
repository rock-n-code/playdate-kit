extension JSON {
    /// A decoded JSON value.
    public indirect enum Value {
        case null
        case bool(Bool)
        case int(Int)
        case float(Float)
        case string(String)
        case array([Value])
        case table([String: Value])
    }
}
