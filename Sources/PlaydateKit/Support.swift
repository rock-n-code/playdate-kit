internal import CPlaydate

/// Internal C-string helpers shared by the wrappers.
///
/// The conversions are implemented manually (rather than with
/// `String(cString:)` / `withCString`) so the module stays within the
/// Embedded Swift subset used for device builds.
extension String {
    /// Creates a string by copying a null-terminated UTF-8 C string.
    init(playdateCString pointer: UnsafePointer<CChar>) {
        var count = 0
        while pointer[count] != 0 { count += 1 }
        let bytes = UnsafeRawBufferPointer(start: pointer, count: count)
        self = String(decoding: bytes, as: UTF8.self)
    }

    /// Creates a string from a nullable C string, or `nil` if the pointer is null.
    init?(playdateCString pointer: UnsafePointer<CChar>?) {
        guard let pointer else { return nil }
        self.init(playdateCString: pointer)
    }

    /// Calls `body` with a temporary null-terminated UTF-8 copy of the
    /// string. The copy lives on the stack for short strings, so calling
    /// this in the update loop does not churn the heap.
    func withPlaydateCString<Result>(_ body: (UnsafePointer<CChar>) -> Result) -> Result {
        let count = utf8.count
        return withUnsafeTemporaryAllocation(of: CChar.self, capacity: count + 1) { buffer in
            var index = 0
            for byte in utf8 {
                buffer[index] = CChar(bitPattern: byte)
                index += 1
            }
            buffer[count] = 0
            return body(buffer.baseAddress.unsafelyUnwrapped)
        }
    }

    /// Calls `body` with a temporary buffer of the string's UTF-8 bytes (not
    /// null-terminated) and its length, for the `(const void*, size_t)` text
    /// APIs. Stack-allocated for short strings.
    func withPlaydateUTF8<Result>(_ body: (UnsafeRawPointer, Int) -> Result) -> Result {
        let count = utf8.count
        return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: count + 1) { buffer in
            var index = 0
            for byte in utf8 {
                buffer[index] = byte
                index += 1
            }
            return body(UnsafeRawPointer(buffer.baseAddress.unsafelyUnwrapped), count)
        }
    }

    /// Copies the string into a newly allocated null-terminated C string.
    /// The caller owns the memory and must free it with `deallocate()`.
    func copiedPlaydateCString() -> UnsafeMutablePointer<CChar> {
        let count = utf8.count
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: count + 1)
        var index = 0
        for byte in utf8 {
            buffer[index] = CChar(bitPattern: byte)
            index += 1
        }
        buffer[count] = 0
        return buffer
    }
}

#if hasFeature(Embedded) && !os(macOS)
/// The Embedded Swift runtime allocates through `posix_memalign(3)`, which
/// the Playdate device C library does not provide. Memory comes from
/// `malloc`, which the SDK's setup code routes to the firmware allocator.
/// The pointer is later released with plain `free`, so it cannot be offset
/// to adjust alignment; the firmware allocator's natural alignment has to
/// satisfy the request, which the precondition asserts.
@_cdecl("posix_memalign")
public func posix_memalign(
    _ memptr: UnsafeMutablePointer<UnsafeMutableRawPointer?>,
    _ alignment: Int,
    _ size: Int
) -> CInt {
    guard let allocation = malloc(size) else { fatalError() }
    precondition(Int(bitPattern: allocation) % alignment == 0)
    memptr.pointee = allocation
    return 0
}
#endif
