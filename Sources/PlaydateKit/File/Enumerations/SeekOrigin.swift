extension File {
    /// The origin used by `Handle.seek(to:from:)`.
    public enum SeekOrigin: Int32, Sendable {
        /// Relative to the beginning of the file.
        case start = 0
        /// Relative to the current offset.
        case current = 1
        /// Relative to the end of the file.
        case end = 2
    }
}
