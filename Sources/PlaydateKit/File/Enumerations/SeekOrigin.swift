extension File {
    /// The origin used by `Handle.seek(to:from:)`.
    public enum SeekOrigin: Int32, Sendable {
        case start = 0
        case current = 1
        case end = 2
    }
}
