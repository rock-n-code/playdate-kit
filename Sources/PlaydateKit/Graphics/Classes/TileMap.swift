internal import CPlaydate

/// `playdate->graphics->tilemap`.
private var tilemapAPI: UnsafePointer<playdate_tilemap> { Playdate.tilemapAPI.unsafelyUnwrapped }

extension Graphics {
    /// A grid of tiles drawn from a bitmap table. Wraps `LCDTileMap`.
    public final class TileMap {
        let pointer: OpaquePointer
        /// The C tilemap holds only a raw pointer to its table.
        private var retainedImageTable: BitmapTable?

        public init() {
            pointer = tilemapAPI.pointee.newTilemap.unsafelyUnwrapped().unsafelyUnwrapped
        }

        deinit {
            tilemapAPI.pointee.freeTilemap.unsafelyUnwrapped(pointer)
        }

        /// Retained while set.
        public var imageTable: BitmapTable? {
            get { retainedImageTable }
            set {
                retainedImageTable = newValue
                tilemapAPI.pointee.setImageTable.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        public func setSize(tilesWide: Int, tilesHigh: Int) {
            tilemapAPI.pointee.setSize.unsafelyUnwrapped(pointer, Int32(tilesWide), Int32(tilesHigh))
        }

        public var size: (tilesWide: Int, tilesHigh: Int) {
            var wide: Int32 = 0, high: Int32 = 0
            tilemapAPI.pointee.getSize.unsafelyUnwrapped(pointer, &wide, &high)
            return (Int(wide), Int(high))
        }

        /// Tile image size times tile counts.
        public var pixelSize: (width: Int, height: Int) {
            var width: UInt32 = 0, height: UInt32 = 0
            tilemapAPI.pointee.getPixelSize.unsafelyUnwrapped(pointer, &width, &height)
            return (Int(width), Int(height))
        }

        /// Sets all tiles row by row, resizing to `rowWidth` × `indexes.count / rowWidth`.
        /// `indexes.count` must be a multiple of `rowWidth`.
        public func setTiles(_ indexes: Span<UInt16>, rowWidth: Int) {
            indexes.withUnsafeBufferPointer { buffer in
                // Non-const in C, but only read (and copied).
                tilemapAPI.pointee.setTiles.unsafelyUnwrapped(
                    pointer, UnsafeMutablePointer(mutating: buffer.baseAddress),
                    Int32(buffer.count), Int32(rowWidth))
            }
        }

        /// Sets all tiles row by row, resizing to `rowWidth` × `indexes.count / rowWidth`.
        /// `indexes.count` must be a multiple of `rowWidth`.
        public func setTiles(_ indexes: [UInt16], rowWidth: Int) {
            indexes.withUnsafeBufferPointer { setTiles($0.span, rowWidth: rowWidth) }
        }

        /// `x` is the column, `y` the row, `index` an image table index.
        public func setTile(x: Int, y: Int, index: UInt16) {
            tilemapAPI.pointee.setTileAtPosition.unsafelyUnwrapped(pointer, Int32(x), Int32(y), index)
        }

        /// The image table index at column `x`, row `y`; `nil` if out of bounds.
        public func tile(x: Int, y: Int) -> Int? {
            let index = tilemapAPI.pointee.getTileAtPosition.unsafelyUnwrapped(pointer, Int32(x), Int32(y))
            return index < 0 ? nil : Int(index)
        }

        /// (x, y) is the upper-left corner, in pixels.
        public func draw(x: Float, y: Float) {
            tilemapAPI.pointee.drawAtPoint.unsafelyUnwrapped(pointer, x, y)
        }
    }
}
