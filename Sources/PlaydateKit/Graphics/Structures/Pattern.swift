extension Graphics {
    /// An 8×8 pattern. Mirrors `LCDPattern`: 8 image rows then 8 mask rows,
    /// one byte per row, one bit per pixel.
    public struct Pattern: Sendable {
        public var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                           UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

        public init(bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)) {
            self.bytes = bytes
        }

        /// An opaque pattern (mask rows all `0xff`).
        public init(rows r: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)) {
            bytes = (r.0, r.1, r.2, r.3, r.4, r.5, r.6, r.7,
                     0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff)
        }
    }
}

// InlineArray needs macOS 26 on the host; device and Linux are unrestricted.
// Conversions reinterpret the same 16 bytes.
@available(macOS 26, *)
extension Graphics.Pattern {
    public init(bytes: [16 of UInt8]) {
        self.init(bytes: unsafeBitCast(bytes, to: Bytes.self))
    }

    /// An opaque pattern (mask rows all `0xff`).
    public init(rows: [8 of UInt8]) {
        self.init(bytes: [16 of UInt8] { $0 < 8 ? rows[$0] : 0xff })
    }

    /// `bytes` as an inline array.
    public var inlineBytes: [16 of UInt8] {
        get { unsafeBitCast(bytes, to: [16 of UInt8].self) }
        set { bytes = unsafeBitCast(newValue, to: Bytes.self) }
    }
}

extension Graphics.Pattern {
    typealias Bytes = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                       UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
}
