//
//  File.swift
//  Wraps `playdate->file` (pd_api_file.h).
//
//  Paths are relative to the game's Data directory (read/write) or the
//  game's pdx (read-only), per the mode used to open them.
//

internal import CPlaydate

private var fileAPI: playdate_file { Playdate.api.file.pointee }

/// The most recent file system error as a thrown error.
private func lastFileError() -> PlaydateError {
    PlaydateError(cString: fileAPI.geterr.unsafelyUnwrapped())
}

/// The file API: access to the game's Data directory and pdx contents.
public enum File {}

extension File {
    // MARK: - Types

    /// How to open a file.
    public struct Options: OptionSet, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }

        /// Read from the game pdx, then the Data directory.
        public static let read = Options(rawValue: kFileRead.rawValue)
        /// Read from the Data directory only.
        public static let readData = Options(rawValue: kFileReadData.rawValue)
        /// Write to the Data directory, truncating an existing file.
        public static let write = Options(rawValue: kFileWrite.rawValue)
        /// Write to the Data directory, appending to an existing file.
        public static let append = Options(rawValue: kFileAppend.rawValue)

        var cValue: FileOptions { FileOptions(rawValue) }
    }

    /// Information about a file or directory, mirroring `FileStat`.
    public struct Stat: Sendable {
        public let isDirectory: Bool
        public let size: UInt32
        public let modified: System.DateTime
    }

    /// The origin used by `Handle.seek(to:from:)`.
    public enum SeekOrigin: Int32, Sendable {
        case start = 0
        case current = 1
        case end = 2
    }

    // MARK: - Directory operations

    /// Calls `each` with the name of every file in `path`. Subdirectory names
    /// end in a slash. Throws if the directory does not exist.
    public static func listFiles(at path: String, showHidden: Bool = false,
                                 _ each: (String) -> Void) throws(PlaydateError) {
        let result = withoutActuallyEscaping(each) { each in
            var callback = each
            return path.withPlaydateCString { cPath in
                withUnsafeMutablePointer(to: &callback) { callbackPointer in
                    fileAPI.listfiles.unsafelyUnwrapped(cPath, { cName, userdata in
                        guard let cName, let userdata else { return }
                        let each = userdata.assumingMemoryBound(to: ((String) -> Void).self).pointee
                        each(String(playdateCString: cName))
                    }, callbackPointer, showHidden ? 1 : 0)
                }
            }
        }
        if result != 0 { throw lastFileError() }
    }

    /// Information about the file or directory at `path`.
    public static func stat(_ path: String) throws(PlaydateError) -> Stat {
        var stat = FileStat()
        let result = path.withPlaydateCString { fileAPI.stat.unsafelyUnwrapped($0, &stat) }
        if result != 0 { throw lastFileError() }
        return Stat(
            isDirectory: stat.isdir != 0,
            size: stat.size,
            modified: System.DateTime(
                year: UInt16(stat.m_year), month: UInt8(stat.m_month), day: UInt8(stat.m_day),
                hour: UInt8(stat.m_hour), minute: UInt8(stat.m_minute), second: UInt8(stat.m_second)))
    }

    /// Creates a directory (and intermediate directories) in the Data directory.
    public static func mkdir(_ path: String) throws(PlaydateError) {
        let result = path.withPlaydateCString { fileAPI.mkdir.unsafelyUnwrapped($0) }
        if result != 0 { throw lastFileError() }
    }

    /// Deletes the file or directory at `path`. Directories require
    /// `recursive` to be deleted with their contents.
    public static func unlink(_ path: String, recursive: Bool = false) throws(PlaydateError) {
        let result = path.withPlaydateCString {
            fileAPI.unlink.unsafelyUnwrapped($0, recursive ? 1 : 0)
        }
        if result != 0 { throw lastFileError() }
    }

    /// Renames (moves) a file in the Data directory, overwriting any existing
    /// file at the destination.
    public static func rename(from: String, to: String) throws(PlaydateError) {
        let result = from.withPlaydateCString { cFrom in
            to.withPlaydateCString { cTo in
                fileAPI.rename.unsafelyUnwrapped(cFrom, cTo)
            }
        }
        if result != 0 { throw lastFileError() }
    }

    // MARK: - Open files

    /// An open file. Wraps `SDFile`. The file is closed on deinit if it has
    /// not been closed explicitly.
    public final class Handle {
        let pointer: UnsafeMutableRawPointer
        private var isClosed = false

        /// Opens the file at `path`.
        public init(path: String, mode: Options) throws(PlaydateError) {
            let pointer = path.withPlaydateCString {
                fileAPI.open.unsafelyUnwrapped($0, mode.cValue)
            }
            guard let pointer else { throw lastFileError() }
            self.pointer = pointer
        }

        deinit {
            if !isClosed {
                _ = fileAPI.close.unsafelyUnwrapped(pointer)
            }
        }

        /// Closes the file. Further operations are invalid.
        public func close() throws(PlaydateError) {
            guard !isClosed else { return }
            isClosed = true
            if fileAPI.close.unsafelyUnwrapped(pointer) != 0 { throw lastFileError() }
        }

        /// Reads up to `buffer.count` bytes into `buffer`. Returns the number
        /// of bytes read; 0 indicates end of file.
        public func read(into buffer: UnsafeMutableRawBufferPointer) throws(PlaydateError) -> Int {
            let result = fileAPI.read.unsafelyUnwrapped(
                pointer, buffer.baseAddress, UInt32(buffer.count))
            if result < 0 { throw lastFileError() }
            return Int(result)
        }

        /// Reads up to `length` bytes and returns them.
        public func read(length: Int) throws(PlaydateError) -> [UInt8] {
            var bytes = [UInt8](repeating: 0, count: length)
            let result = bytes.withUnsafeMutableBytes { buffer in
                fileAPI.read.unsafelyUnwrapped(pointer, buffer.baseAddress, UInt32(buffer.count))
            }
            if result < 0 { throw lastFileError() }
            bytes.removeLast(length - Int(result))
            return bytes
        }

        /// Writes the buffer to the file. Returns the number of bytes written.
        @discardableResult
        public func write(_ buffer: UnsafeRawBufferPointer) throws(PlaydateError) -> Int {
            let result = fileAPI.write.unsafelyUnwrapped(
                pointer, buffer.baseAddress, UInt32(buffer.count))
            if result < 0 { throw lastFileError() }
            return Int(result)
        }

        /// Writes the bytes to the file. Returns the number of bytes written.
        @discardableResult
        public func write(_ bytes: [UInt8]) throws(PlaydateError) -> Int {
            let result = bytes.withUnsafeBytes { buffer in
                fileAPI.write.unsafelyUnwrapped(pointer, buffer.baseAddress, UInt32(buffer.count))
            }
            if result < 0 { throw lastFileError() }
            return Int(result)
        }

        /// Writes the string's UTF-8 to the file. Returns the bytes written.
        @discardableResult
        public func write(_ string: String) throws(PlaydateError) -> Int {
            try write(Array(string.utf8))
        }

        /// Flushes buffered writes to disk. Returns the bytes written.
        @discardableResult
        public func flush() throws(PlaydateError) -> Int {
            let result = fileAPI.flush.unsafelyUnwrapped(pointer)
            if result < 0 { throw lastFileError() }
            return Int(result)
        }

        /// The current read/write offset.
        public func tell() throws(PlaydateError) -> Int {
            let result = fileAPI.tell.unsafelyUnwrapped(pointer)
            if result < 0 { throw lastFileError() }
            return Int(result)
        }

        /// Moves the read/write offset to `offset` relative to `origin`.
        public func seek(to offset: Int, from origin: SeekOrigin = .start) throws(PlaydateError) {
            if fileAPI.seek.unsafelyUnwrapped(pointer, Int32(offset), origin.rawValue) != 0 {
                throw lastFileError()
            }
        }
    }
}
