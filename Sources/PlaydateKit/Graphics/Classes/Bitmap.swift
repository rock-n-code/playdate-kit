internal import CPlaydate

extension Graphics {
    /// A drawable image and drawing target. Wraps `LCDBitmap`. Bitmaps borrowed from
    /// tables, fonts, video players, or the system live only as long as their owner.
    public final class Bitmap {
        let pointer: OpaquePointer
        /// Whether deinit frees the `LCDBitmap`.
        let isOwned: Bool
        /// Kept alive because this bitmap shares its pixels.
        private let owner: Bitmap?

        init(pointer: OpaquePointer, isOwned: Bool, owner: Bitmap? = nil) {
            self.pointer = pointer
            self.isOwned = isOwned
            self.owner = owner
        }

        public convenience init(width: Int, height: Int, backgroundColor: Color = .clear) {
            let pointer = backgroundColor.withLCDColor {
                gfx.pointee.newBitmap.unsafelyUnwrapped(Int32(width), Int32(height), $0)
            }
            self.init(pointer: pointer.unsafelyUnwrapped, isOwned: true)
        }

        /// `path` is in the game's pdx or Data directory.
        public convenience init(path: String) throws(PlaydateError) {
            var error: UnsafePointer<CChar>?
            let pointer = path.withCString { gfx.pointee.loadBitmap.unsafelyUnwrapped($0, &error) }
            guard let pointer else { throw PlaydateError(cString: error) }
            self.init(pointer: pointer, isOwned: true)
        }

        deinit {
            if isOwned {
                gfx.pointee.freeBitmap.unsafelyUnwrapped(pointer)
            }
        }

        // MARK: Size and pixel data

        public var data: Data {
            let raw = rawData()
            return Data(width: raw.width, height: raw.height, rowBytes: raw.rowBytes,
                        hasMask: raw.mask != nil)
        }

        /// 1 bit per pixel, MSB first, `height` rows of `rowBytes` bytes. The span is valid
        /// only inside `body`, and empty if the bitmap has no data.
        public func withPixelData<Result, Failure: Error>(
            _ body: (inout MutableSpan<UInt8>) throws(Failure) -> Result
        ) throws(Failure) -> Result {
            let raw = rawData()
            var span = UnsafeMutableBufferPointer(
                start: raw.data, count: raw.data == nil ? 0 : raw.height * raw.rowBytes).mutableSpan
            return try body(&span)
        }

        /// Laid out like the pixel data; valid only inside `body`. Returns `nil` without
        /// calling `body` if the bitmap has no mask.
        public func withMaskData<Result, Failure: Error>(
            _ body: (inout MutableSpan<UInt8>) throws(Failure) -> Result
        ) throws(Failure) -> Result? {
            let raw = rawData()
            guard let mask = raw.mask else { return nil }
            var span = UnsafeMutableBufferPointer(start: mask, count: raw.height * raw.rowBytes).mutableSpan
            return try body(&span)
        }

        private func rawData() -> (width: Int, height: Int, rowBytes: Int,
                                   mask: UnsafeMutablePointer<UInt8>?, data: UnsafeMutablePointer<UInt8>?) {
            var width: Int32 = 0, height: Int32 = 0, rowBytes: Int32 = 0
            var mask: UnsafeMutablePointer<UInt8>?
            var data: UnsafeMutablePointer<UInt8>?
            gfx.pointee.getBitmapData.unsafelyUnwrapped(pointer, &width, &height, &rowBytes, &mask, &data)
            return (Int(width), Int(height), Int(rowBytes), mask, data)
        }

        /// Saves a `getBitmapData` call per access. Reset by `load(path:)`, the only resizer.
        private var cachedSize: (width: Int, height: Int)?

        private var size: (width: Int, height: Int) {
            if let cachedSize { return cachedSize }
            let raw = rawData()
            let size = (raw.width, raw.height)
            cachedSize = size
            return size
        }

        /// Width, in pixels.
        public var width: Int { size.width }
        /// Height, in pixels.
        public var height: Int { size.height }

        /// `.black` or `.white`, or `.clear` if out of bounds or masked out.
        public func pixel(x: Int, y: Int) -> SolidColor {
            SolidColor(gfx.pointee.getBitmapPixel.unsafelyUnwrapped(pointer, Int32(x), Int32(y)))
        }

        // MARK: Operations

        /// Replaces the contents, and possibly the size, with the image at `path`.
        public func load(path: String) throws(PlaydateError) {
            var error: UnsafePointer<CChar>?
            path.withCString { gfx.pointee.loadIntoBitmap.unsafelyUnwrapped($0, pointer, &error) }
            cachedSize = nil
            if let error { throw PlaydateError(cString: error) }
        }

        public func clear(color: Color) {
            color.withLCDColor { gfx.pointee.clearBitmap.unsafelyUnwrapped(pointer, $0) }
        }

        public func copy() -> Bitmap {
            Bitmap(pointer: gfx.pointee.copyBitmap.unsafelyUnwrapped(pointer).unsafelyUnwrapped, isOwned: true)
        }

        /// `degrees` is clockwise. Returns `nil` on failure.
        public func rotated(by degrees: Float, xScale: Float = 1, yScale: Float = 1) -> Bitmap? {
            var allocatedSize: Int32 = 0
            guard let rotated = gfx.pointee.rotatedBitmap.unsafelyUnwrapped(
                pointer, degrees, xScale, yScale, &allocatedSize) else { return nil }
            return Bitmap(pointer: rotated, isOwned: true)
        }

        /// Returns `false` if `mask` is `nil` or a different size.
        @discardableResult
        public func setMask(_ mask: Bitmap?) -> Bool {
            gfx.pointee.setBitmapMask.unsafelyUnwrapped(pointer, mask?.pointer) != 0
        }

        /// Shares this bitmap's mask data, and keeps this bitmap alive.
        public var mask: Bitmap? {
            // Owned by the caller; pixels are shared with `self`.
            guard let mask = gfx.pointee.getBitmapMask.unsafelyUnwrapped(pointer) else { return nil }
            return Bitmap(pointer: mask, isOwned: true, owner: self)
        }

        /// Whether opaque pixels of both bitmaps overlap within the non-empty `rect`.
        /// `false` if either bitmap lies entirely outside `rect`.
        public func checkMaskCollision(x: Int, y: Int, flip: BitmapFlip = .unflipped,
                                       other: Bitmap, otherX: Int, otherY: Int,
                                       otherFlip: BitmapFlip = .unflipped,
                                       in rect: Rect) -> Bool {
            gfx.pointee.checkMaskCollision.unsafelyUnwrapped(
                pointer, Int32(x), Int32(y), flip.cValue,
                other.pointer, Int32(otherX), Int32(otherY), otherFlip.cValue,
                rect.cValue) != 0
        }

        // MARK: Drawing

        /// (x, y) is the upper-left corner.
        public func draw(x: Int, y: Int, flip: BitmapFlip = .unflipped) {
            gfx.pointee.drawBitmap.unsafelyUnwrapped(pointer, Int32(x), Int32(y), flip.cValue)
        }

        /// (x, y) is the upper-left corner. Negative scales flip the bitmap.
        public func drawScaled(x: Int, y: Int, xScale: Float, yScale: Float) {
            gfx.pointee.drawScaledBitmap.unsafelyUnwrapped(pointer, Int32(x), Int32(y), xScale, yScale)
        }

        /// Scales, then rotates, placing the anchor (`centerX`, `centerY`) at (x, y). Anchors
        /// are proportional: (0.5, 0.5) is the center, (0, 0) the unrotated upper-left.
        public func drawRotated(x: Int, y: Int, degrees: Float,
                                centerX: Float = 0.5, centerY: Float = 0.5,
                                xScale: Float = 1, yScale: Float = 1) {
            gfx.pointee.drawRotatedBitmap.unsafelyUnwrapped(pointer, Int32(x), Int32(y), degrees,
                                                    centerX, centerY, xScale, yScale)
        }

        /// Tiles the `width` × `height` rect whose upper-left corner is (x, y).
        public func tile(x: Int, y: Int, width: Int, height: Int, flip: BitmapFlip = .unflipped) {
            gfx.pointee.tileBitmap.unsafelyUnwrapped(pointer, Int32(x), Int32(y),
                                             Int32(width), Int32(height), flip.cValue)
        }
    }
}
