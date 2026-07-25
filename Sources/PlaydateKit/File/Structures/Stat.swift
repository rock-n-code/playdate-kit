extension File {
    /// Information about a file or directory, mirroring `FileStat`.
    public struct Stat: Sendable {
        /// Whether the path is a directory.
        public let isDirectory: Bool
        /// The file's size, in bytes.
        public let size: UInt32
        /// The time the file was last modified.
        public let modified: System.DateTime
    }
}
