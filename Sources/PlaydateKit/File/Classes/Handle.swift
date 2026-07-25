internal import CPlaydate

extension File {
    /// An open file. Wraps `SDFile`. The file is closed on deinit if it has
    /// not been closed explicitly.
    public final class Handle {
        let pointer: UnsafeMutableRawPointer
        private var isClosed = false

        /// Opens the file at `path`.
        public init(path: String, mode: Options) throws(PlaydateError) {
            let pointer = path.withPlaydateCString {
                fileAPI.pointee.open.unsafelyUnwrapped($0, mode.cValue)
            }
            guard let pointer else { throw lastFileError() }
            self.pointer = pointer
        }

        deinit {
            if !isClosed {
                _ = fileAPI.pointee.close.unsafelyUnwrapped(pointer)
            }
        }

        /// Closes the file. Further operations are invalid.
        public func close() throws(PlaydateError) {
            guard !isClosed else { return }
            isClosed = true
            if fileAPI.pointee.close.unsafelyUnwrapped(pointer) != 0 { throw lastFileError() }
        }

        /// Reads up to `buffer.count` bytes into `buffer`. Returns the number
        /// of bytes read; 0 indicates end of file.
        public func read(into buffer: UnsafeMutableRawBufferPointer) throws(PlaydateError) -> Int {
            let result = fileAPI.pointee.read.unsafelyUnwrapped(
                pointer, buffer.baseAddress, UInt32(buffer.count))
            if result < 0 { throw lastFileError() }
            return Int(result)
        }

        /// Reads up to `length` bytes and returns them.
        public func read(length: Int) throws(PlaydateError) -> [UInt8] {
            var bytes = [UInt8](repeating: 0, count: length)
            let result = bytes.withUnsafeMutableBytes { buffer in
                fileAPI.pointee.read.unsafelyUnwrapped(pointer, buffer.baseAddress, UInt32(buffer.count))
            }
            if result < 0 { throw lastFileError() }
            bytes.removeLast(length - Int(result))
            return bytes
        }

        /// Writes the buffer to the file. Returns the number of bytes written.
        @discardableResult
        public func write(_ buffer: UnsafeRawBufferPointer) throws(PlaydateError) -> Int {
            let result = fileAPI.pointee.write.unsafelyUnwrapped(
                pointer, buffer.baseAddress, UInt32(buffer.count))
            if result < 0 { throw lastFileError() }
            return Int(result)
        }

        /// Writes the bytes to the file. Returns the number of bytes written.
        @discardableResult
        public func write(_ bytes: [UInt8]) throws(PlaydateError) -> Int {
            let result = bytes.withUnsafeBytes { buffer in
                fileAPI.pointee.write.unsafelyUnwrapped(pointer, buffer.baseAddress, UInt32(buffer.count))
            }
            if result < 0 { throw lastFileError() }
            return Int(result)
        }

        /// Writes the string's UTF-8 to the file. Returns the bytes written.
        @discardableResult
        public func write(_ string: String) throws(PlaydateError) -> Int {
            let result = string.withPlaydateUTF8 { bytes, count in
                fileAPI.pointee.write.unsafelyUnwrapped(pointer, bytes, UInt32(count))
            }
            if result < 0 { throw lastFileError() }
            return Int(result)
        }

        /// Flushes buffered writes to disk. Returns the bytes written.
        @discardableResult
        public func flush() throws(PlaydateError) -> Int {
            let result = fileAPI.pointee.flush.unsafelyUnwrapped(pointer)
            if result < 0 { throw lastFileError() }
            return Int(result)
        }

        /// The current read/write offset.
        public func tell() throws(PlaydateError) -> Int {
            let result = fileAPI.pointee.tell.unsafelyUnwrapped(pointer)
            if result < 0 { throw lastFileError() }
            return Int(result)
        }

        /// Moves the read/write offset to `offset` relative to `origin`.
        public func seek(to offset: Int, from origin: SeekOrigin = .start) throws(PlaydateError) {
            if fileAPI.pointee.seek.unsafelyUnwrapped(pointer, Int32(offset), origin.rawValue) != 0 {
                throw lastFileError()
            }
        }
    }
}
