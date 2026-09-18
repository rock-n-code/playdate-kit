extension File {
    /// Origin for `Handle.seek(to:from:)`: `SEEK_SET`, `SEEK_CUR`, `SEEK_END`.
    public enum SeekOrigin: Int32, Sendable {
        case start = 0
        case current = 1
        case end = 2
    }
}
