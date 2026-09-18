internal import CPlaydate

/// C-string helpers. Strings passed to C use `withCString`, which doesn't copy.
extension String {
    /// `nil` if `pointer` is null.
    init?(playdateCString pointer: UnsafePointer<CChar>?) {
        guard let pointer else { return nil }
        self.init(cString: pointer)
    }

    /// New null-terminated copy; the caller frees it with `deallocate()`.
    func copiedPlaydateCString() -> UnsafeMutablePointer<CChar> {
        withCString { cString in
            let count = utf8.count + 1
            let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: count)
            buffer.initialize(from: cString, count: count)
            return buffer
        }
    }
}

#if hasFeature(Embedded) && !os(macOS)
/// `posix_memalign(3)` for the Embedded Swift runtime; the device C library lacks it.
/// Uses `malloc` (the firmware allocator). Freed with plain `free`, so no alignment offset:
/// the precondition checks `malloc`'s alignment suffices. Traps on failure; else returns 0.
@c(posix_memalign)
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
