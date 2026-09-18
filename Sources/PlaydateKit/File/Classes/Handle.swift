internal import CPlaydate

extension File {
    /// An open file. Wraps `SDFile`. Non-copyable: closes when the handle goes out of
    /// scope, or earlier via consuming `close()`. At most 64 files may be open.
    public struct Handle: ~Copyable {
        let pointer: UnsafeMutableRawPointer

        /// Opens the file at `path` in `mode`.
        public init(path: String, mode: Options) throws(PlaydateError) {
            let pointer = path.withCString {
                fileAPI.pointee.open.unsafelyUnwrapped($0, mode.cValue)
            }
            guard let pointer else { throw lastFileError() }
            self.pointer = pointer
        }

        deinit {
            _ = fileAPI.pointee.close.unsafelyUnwrapped(pointer)
        }

        /// Closes the file, consuming the handle.
        // `@export(interface)` lets `discard` compile in Embedded Swift on the 6.4 toolchain.
        @export(interface)
        public consuming func close() throws(PlaydateError) {
            let pointer = self.pointer
            discard self
            if fileAPI.pointee.close.unsafelyUnwrapped(pointer) != 0 { throw lastFileError() }
        }

        /// Reads up to `buffer.count` bytes; returns the count read, 0 at end of file.
        public func read(into buffer: inout MutableSpan<UInt8>) throws(PlaydateError) -> Int {
            let result = buffer.withUnsafeMutableBufferPointer { buffer in
                fileAPI.pointee.read.unsafelyUnwrapped(pointer, buffer.baseAddress, UInt32(buffer.count))
            }
            if result < 0 { throw lastFileError() }
            return Int(result)
        }

        /// Reads up to `length` bytes; shorter near end of file, empty at it.
        public func read(length: Int) throws(PlaydateError) -> [UInt8] {
            try [UInt8](capacity: length) { output throws(PlaydateError) in
                let result = output.withUnsafeMutableBufferPointer { buffer, initializedCount in
                    let result = fileAPI.pointee.read.unsafelyUnwrapped(
                        pointer, buffer.baseAddress, UInt32(buffer.count))
                    initializedCount = max(Int(result), 0)
                    return result
                }
                if result < 0 { throw lastFileError() }
            }
        }

        /// Writes `bytes`; returns the count written.
        @discardableResult
        public func write(_ bytes: Span<UInt8>) throws(PlaydateError) -> Int {
            let result = bytes.withUnsafeBufferPointer { buffer in
                fileAPI.pointee.write.unsafelyUnwrapped(pointer, buffer.baseAddress, UInt32(buffer.count))
            }
            if result < 0 { throw lastFileError() }
            return Int(result)
        }

        /// Writes `bytes`; returns the count written.
        @discardableResult
        public func write(_ bytes: [UInt8]) throws(PlaydateError) -> Int {
            try bytes.withUnsafeBufferPointer { buffer throws(PlaydateError) in
                try write(buffer.span)
            }
        }

        /// Writes `string` as UTF-8, without a NUL terminator; returns the count written.
        @discardableResult
        public func write(_ string: String) throws(PlaydateError) -> Int {
            let result = string.withCString { cString in
                fileAPI.pointee.write.unsafelyUnwrapped(pointer, cString, UInt32(string.utf8.count))
            }
            if result < 0 { throw lastFileError() }
            return Int(result)
        }

        /// Flushes buffered writes; returns the count written.
        @discardableResult
        public func flush() throws(PlaydateError) -> Int {
            let result = fileAPI.pointee.flush.unsafelyUnwrapped(pointer)
            if result < 0 { throw lastFileError() }
            return Int(result)
        }

        /// The current read/write offset, in bytes.
        public func tell() throws(PlaydateError) -> Int {
            let result = fileAPI.pointee.tell.unsafelyUnwrapped(pointer)
            if result < 0 { throw lastFileError() }
            return Int(result)
        }

        /// Moves the read/write offset to `offset` bytes from `origin`.
        public func seek(to offset: Int, from origin: SeekOrigin = .start) throws(PlaydateError) {
            if fileAPI.pointee.seek.unsafelyUnwrapped(pointer, Int32(offset), origin.rawValue) != 0 {
                throw lastFileError()
            }
        }
    }
}
