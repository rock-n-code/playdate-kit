extension Graphics.Bitmap {
    /// A bitmap's layout. Read pixels with `withPixelData(_:)` and `withMaskData(_:)`.
    public struct Data: Sendable {
        /// Width, in pixels.
        public let width: Int
        /// Height, in pixels.
        public let height: Int
        /// Row stride of the pixel and mask data, in bytes.
        public let rowBytes: Int
        public let hasMask: Bool
    }
}
