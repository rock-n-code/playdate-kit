//
//  GraphicsTileMap.swift
//  TileMap wrapper around LCDTileMap (playdate->graphics->tilemap).
//

internal import CPlaydate

private var tilemapAPI: UnsafePointer<playdate_tilemap> { gfx.pointee.tilemap.unsafelyUnwrapped }

extension Graphics {
    /// A grid of tiles drawn from a bitmap table. Wraps `LCDTileMap`.
    public final class TileMap {
        let pointer: OpaquePointer
        /// The image table is retained so the tilemap's tiles stay valid.
        private var retainedImageTable: BitmapTable?

        public init() {
            pointer = tilemapAPI.pointee.newTilemap.unsafelyUnwrapped().unsafelyUnwrapped
        }

        deinit {
            tilemapAPI.pointee.freeTilemap.unsafelyUnwrapped(pointer)
        }

        /// The bitmap table the tile indexes refer to.
        public var imageTable: BitmapTable? {
            get { retainedImageTable }
            set {
                retainedImageTable = newValue
                tilemapAPI.pointee.setImageTable.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        /// Sets the tilemap's size in tiles.
        public func setSize(tilesWide: Int, tilesHigh: Int) {
            tilemapAPI.pointee.setSize.unsafelyUnwrapped(pointer, Int32(tilesWide), Int32(tilesHigh))
        }

        /// The tilemap's size in tiles.
        public var size: (tilesWide: Int, tilesHigh: Int) {
            var wide: Int32 = 0, high: Int32 = 0
            tilemapAPI.pointee.getSize.unsafelyUnwrapped(pointer, &wide, &high)
            return (Int(wide), Int(high))
        }

        /// The tilemap's total size in pixels.
        public var pixelSize: (width: Int, height: Int) {
            var width: UInt32 = 0, height: UInt32 = 0
            tilemapAPI.pointee.getPixelSize.unsafelyUnwrapped(pointer, &width, &height)
            return (Int(width), Int(height))
        }

        /// Fills the tilemap with `indexes`, `rowWidth` tiles per row. The
        /// tilemap is resized to fit.
        public func setTiles(_ indexes: [UInt16], rowWidth: Int) {
            var indexes = indexes
            indexes.withUnsafeMutableBufferPointer { buffer in
                tilemapAPI.pointee.setTiles.unsafelyUnwrapped(pointer, buffer.baseAddress,
                                                      Int32(buffer.count), Int32(rowWidth))
            }
        }

        /// Sets the tile index at position (x, y).
        public func setTile(x: Int, y: Int, index: UInt16) {
            tilemapAPI.pointee.setTileAtPosition.unsafelyUnwrapped(pointer, Int32(x), Int32(y), index)
        }

        /// The tile index at position (x, y), or `nil` if out of bounds.
        public func tile(x: Int, y: Int) -> Int? {
            let index = tilemapAPI.pointee.getTileAtPosition.unsafelyUnwrapped(pointer, Int32(x), Int32(y))
            return index < 0 ? nil : Int(index)
        }

        /// Draws the tilemap with its upper-left corner at (x, y).
        public func draw(x: Float, y: Float) {
            tilemapAPI.pointee.drawAtPoint.unsafelyUnwrapped(pointer, x, y)
        }
    }
}
