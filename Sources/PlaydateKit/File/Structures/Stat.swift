extension File {
    /// File or directory information. Mirrors `FileStat`.
    public struct Stat: Sendable {
        public let isDirectory: Bool
        /// Size in bytes.
        public let size: UInt32
        /// Last modification time; `weekday` is 0 (unset).
        public let modified: System.DateTime
    }
}
