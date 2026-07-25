extension Graphics.Bitmap {
    /// The bitmap's dimensions, row stride, and raw pixel/mask storage.
    /// The pointers are owned by the bitmap.
    public struct Data {
        public let width: Int
        public let height: Int
        public let rowBytes: Int
        public let mask: UnsafeMutablePointer<UInt8>?
        public let data: UnsafeMutablePointer<UInt8>?
    }
}
