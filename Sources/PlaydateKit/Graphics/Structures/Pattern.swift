extension Graphics {
    /// An 8×8 two-color pattern: 8 rows of image data followed by 8 rows of mask.
    public struct Pattern: Sendable {
        /// The pattern's 8 rows of image data followed by 8 rows of mask,
        /// one byte per row.
        public var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                           UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

        /// Creates a pattern from 8 rows of image data and 8 rows of mask.
        public init(bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)) {
            self.bytes = bytes
        }

        /// Creates an opaque pattern from 8 rows of image data.
        public init(rows r: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)) {
            bytes = (r.0, r.1, r.2, r.3, r.4, r.5, r.6, r.7,
                     0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff)
        }
    }
}
