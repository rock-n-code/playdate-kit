extension Graphics.Bitmap {
    /// The bitmap's dimensions, row stride, and raw pixel/mask storage.
    /// The pointers are owned by the bitmap.
    public struct Data {
        /// The bitmap's width, in pixels.
        public let width: Int
        /// The bitmap's height, in pixels.
        public let height: Int
        /// The stride of one row of pixel data, in bytes.
        public let rowBytes: Int
        /// The bitmap's mask data, or `nil` if it has no mask. One bit per
        /// pixel; rows are `rowBytes` wide.
        public let mask: UnsafeMutablePointer<UInt8>?
        /// The bitmap's pixel data. One bit per pixel; rows are `rowBytes`
        /// wide.
        public let data: UnsafeMutablePointer<UInt8>?
    }
}
