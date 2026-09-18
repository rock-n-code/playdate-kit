internal import CPlaydate

extension File {
    /// How to open a file. Wraps `FileOptions`.
    public struct Options: OptionSet, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }

        /// Read from the pdx only; add `.readData` to search the Data directory first.
        public static let read = Options(rawValue: UInt32(kFileRead.rawValue))
        /// Read from the Data directory.
        public static let readData = Options(rawValue: UInt32(kFileReadData.rawValue))
        /// Write to the Data directory, truncating.
        public static let write = Options(rawValue: UInt32(kFileWrite.rawValue))
        /// Write to the Data directory, appending.
        public static let append = Options(rawValue: UInt32(kFileAppend.rawValue))

        var cValue: FileOptions { FileOptions(FileOptions.RawValue(rawValue)) }
    }
}
