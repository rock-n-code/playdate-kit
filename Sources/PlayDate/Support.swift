//
//  Support.swift
//  Internal helpers shared by the wrappers.
//
//  C-string conversions are implemented manually (rather than with
//  `String(cString:)` / `withCString`) so the module stays within the
//  Embedded Swift subset used for device builds.
//

internal import CPlaydate

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

    /// Calls `body` with a temporary null-terminated UTF-8 copy of the string.
    func withPlaydateCString<Result>(_ body: (UnsafePointer<CChar>) -> Result) -> Result {
        var utf8 = ContiguousArray(self.utf8)
        utf8.append(0)
        return utf8.withUnsafeBufferPointer { buffer in
            buffer.withMemoryRebound(to: CChar.self) { rebound in
                body(rebound.baseAddress.unsafelyUnwrapped)
            }
        }
    }

    /// Copies the string into a newly allocated null-terminated C string.
    /// The caller owns the memory and must free it with `deallocate()`.
    func copiedPlaydateCString() -> UnsafeMutablePointer<CChar> {
        let utf8 = ContiguousArray(self.utf8)
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: utf8.count + 1)
        for (index, byte) in utf8.enumerated() {
            buffer[index] = CChar(bitPattern: byte)
        }
        buffer[utf8.count] = 0
        return buffer
    }
}
