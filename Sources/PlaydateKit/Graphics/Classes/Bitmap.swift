internal import CPlaydate

extension Graphics {
    /// An image that can be drawn to the screen or used as a drawing target.
    /// Wraps `LCDBitmap`.
    public final class Bitmap {
        let pointer: OpaquePointer
        /// Whether this wrapper owns the underlying `LCDBitmap` and frees it
        /// on deinit. Bitmaps vended by tables or the system are not owned;
        /// keep their owner alive while using them.
        let isOwned: Bool

        init(pointer: OpaquePointer, isOwned: Bool) {
            self.pointer = pointer
            self.isOwned = isOwned
        }

        /// Allocates a new bitmap filled with `backgroundColor`.
        public convenience init(width: Int, height: Int, backgroundColor: Color = .clear) {
            let pointer = backgroundColor.withLCDColor {
                gfx.pointee.newBitmap.unsafelyUnwrapped(Int32(width), Int32(height), $0)
            }
            self.init(pointer: pointer.unsafelyUnwrapped, isOwned: true)
        }

        /// Loads a bitmap from a file in the game's pdx or Data directory.
        public convenience init(path: String) throws(PlaydateError) {
            var error: UnsafePointer<CChar>?
            let pointer = path.withPlaydateCString { gfx.pointee.loadBitmap.unsafelyUnwrapped($0, &error) }
            guard let pointer else { throw PlaydateError(cString: error) }
            self.init(pointer: pointer, isOwned: true)
        }

        deinit {
            if isOwned {
                gfx.pointee.freeBitmap.unsafelyUnwrapped(pointer)
            }
        }

        // MARK: Properties

        public var data: Data {
            var width: Int32 = 0, height: Int32 = 0, rowBytes: Int32 = 0
            var mask: UnsafeMutablePointer<UInt8>?
            var data: UnsafeMutablePointer<UInt8>?
            gfx.pointee.getBitmapData.unsafelyUnwrapped(pointer, &width, &height, &rowBytes, &mask, &data)
            return Data(width: Int(width), height: Int(height), rowBytes: Int(rowBytes),
                        mask: mask, data: data)
        }

        /// Cached dimensions, so `width`/`height` don't pay a full
        /// `getBitmapData` round-trip per access. Only `load(path:)` can
        /// change a bitmap's size, which resets the cache.
        private var cachedSize: (width: Int, height: Int)?

        private var size: (width: Int, height: Int) {
            if let cachedSize { return cachedSize }
            let data = self.data
            let size = (data.width, data.height)
            cachedSize = size
            return size
        }

        public var width: Int { size.width }
        public var height: Int { size.height }

        /// The color of the pixel at (x, y).
        public func pixel(x: Int, y: Int) -> SolidColor {
            SolidColor(gfx.pointee.getBitmapPixel.unsafelyUnwrapped(pointer, Int32(x), Int32(y)))
        }

        // MARK: Operations

        /// Replaces the bitmap's contents with the image at `path`.
        public func load(path: String) throws(PlaydateError) {
            var error: UnsafePointer<CChar>?
            path.withPlaydateCString { gfx.pointee.loadIntoBitmap.unsafelyUnwrapped($0, pointer, &error) }
            cachedSize = nil
            if let error { throw PlaydateError(cString: error) }
        }

        /// Fills the bitmap with `color`.
        public func clear(color: Color) {
            color.withLCDColor { gfx.pointee.clearBitmap.unsafelyUnwrapped(pointer, $0) }
        }

        public func copy() -> Bitmap {
            Bitmap(pointer: gfx.pointee.copyBitmap.unsafelyUnwrapped(pointer).unsafelyUnwrapped, isOwned: true)
        }

        /// Returns a new bitmap rotated by `degrees` (clockwise) and scaled.
        public func rotated(by degrees: Float, xScale: Float = 1, yScale: Float = 1) -> Bitmap? {
            var allocatedSize: Int32 = 0
            guard let rotated = gfx.pointee.rotatedBitmap.unsafelyUnwrapped(
                pointer, degrees, xScale, yScale, &allocatedSize) else { return nil }
            return Bitmap(pointer: rotated, isOwned: true)
        }

        /// Sets a mask image. The mask must match the bitmap's dimensions.
        @discardableResult
        public func setMask(_ mask: Bitmap?) -> Bool {
            gfx.pointee.setBitmapMask.unsafelyUnwrapped(pointer, mask?.pointer) != 0
        }

        /// The bitmap's mask, if any. The returned bitmap references storage
        /// owned by this bitmap.
        public var mask: Bitmap? {
            guard let mask = gfx.pointee.getBitmapMask.unsafelyUnwrapped(pointer) else { return nil }
            return Bitmap(pointer: mask, isOwned: false)
        }

        /// Tests whether the opaque pixels of two bitmaps overlap within
        /// `rect`, given each bitmap's position and flip.
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

        /// Draws the bitmap with its upper-left corner at (x, y).
        public func draw(x: Int, y: Int, flip: BitmapFlip = .unflipped) {
            gfx.pointee.drawBitmap.unsafelyUnwrapped(pointer, Int32(x), Int32(y), flip.cValue)
        }

        /// Draws the bitmap scaled by (xScale, yScale) with its upper-left
        /// corner at (x, y).
        public func drawScaled(x: Int, y: Int, xScale: Float, yScale: Float) {
            gfx.pointee.drawScaledBitmap.unsafelyUnwrapped(pointer, Int32(x), Int32(y), xScale, yScale)
        }

        /// Draws the bitmap rotated by `degrees` around its anchor point,
        /// where (0.5, 0.5) is the center.
        public func drawRotated(x: Int, y: Int, degrees: Float,
                                centerX: Float = 0.5, centerY: Float = 0.5,
                                xScale: Float = 1, yScale: Float = 1) {
            gfx.pointee.drawRotatedBitmap.unsafelyUnwrapped(pointer, Int32(x), Int32(y), degrees,
                                                    centerX, centerY, xScale, yScale)
        }

        /// Tiles the bitmap over the given area.
        public func tile(x: Int, y: Int, width: Int, height: Int, flip: BitmapFlip = .unflipped) {
            gfx.pointee.tileBitmap.unsafelyUnwrapped(pointer, Int32(x), Int32(y),
                                             Int32(width), Int32(height), flip.cValue)
        }
    }
}
