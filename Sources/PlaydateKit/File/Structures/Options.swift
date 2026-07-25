internal import CPlaydate

extension File {
    /// How to open a file.
    public struct Options: OptionSet, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }

        /// Read from the game pdx, then the Data directory.
        public static let read = Options(rawValue: UInt32(kFileRead.rawValue))
        /// Read from the Data directory only.
        public static let readData = Options(rawValue: UInt32(kFileReadData.rawValue))
        /// Write to the Data directory, truncating an existing file.
        public static let write = Options(rawValue: UInt32(kFileWrite.rawValue))
        /// Write to the Data directory, appending to an existing file.
        public static let append = Options(rawValue: UInt32(kFileAppend.rawValue))

        var cValue: FileOptions { FileOptions(FileOptions.RawValue(rawValue)) }
    }
}
