extension File {
    /// Information about a file or directory, mirroring `FileStat`.
    public struct Stat: Sendable {
        public let isDirectory: Bool
        public let size: UInt32
        public let modified: System.DateTime
    }
}
