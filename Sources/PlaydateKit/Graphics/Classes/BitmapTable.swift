internal import CPlaydate

extension Graphics {
    /// A collection of bitmaps loaded from an image table. Wraps `LCDBitmapTable`.
    public final class BitmapTable {
        let pointer: OpaquePointer

        init(pointer: OpaquePointer) {
            self.pointer = pointer
        }

        /// Allocates a table with room for `count` bitmaps of the given size.
        public convenience init(count: Int, width: Int, height: Int) {
            let pointer = gfx.pointee.newBitmapTable.unsafelyUnwrapped(Int32(count), Int32(width), Int32(height))
            self.init(pointer: pointer.unsafelyUnwrapped)
        }

        /// Loads an image table from a file.
        public convenience init(path: String) throws(PlaydateError) {
            var error: UnsafePointer<CChar>?
            let pointer = path.withPlaydateCString { gfx.pointee.loadBitmapTable.unsafelyUnwrapped($0, &error) }
            guard let pointer else { throw PlaydateError(cString: error) }
            self.init(pointer: pointer)
        }

        deinit {
            gfx.pointee.freeBitmapTable.unsafelyUnwrapped(pointer)
        }

        /// Replaces the table's contents with the image table at `path`.
        public func load(path: String) throws(PlaydateError) {
            var error: UnsafePointer<CChar>?
            path.withPlaydateCString { gfx.pointee.loadIntoBitmapTable.unsafelyUnwrapped($0, pointer, &error) }
            if let error { throw PlaydateError(cString: error) }
        }

        /// The bitmap at `index`, or `nil` if out of range. The bitmap
        /// references storage owned by the table; keep the table alive while
        /// using it.
        public func bitmap(at index: Int) -> Bitmap? {
            guard let bitmap = gfx.pointee.getTableBitmap.unsafelyUnwrapped(pointer, Int32(index)) else {
                return nil
            }
            return Bitmap(pointer: bitmap, isOwned: false)
        }

        /// The number of bitmaps in the table and the number of cells per row
        /// of the source image.
        public var info: (count: Int, cellsWide: Int) {
            var count: Int32 = 0, width: Int32 = 0
            gfx.pointee.getBitmapTableInfo.unsafelyUnwrapped(pointer, &count, &width)
            return (Int(count), Int(width))
        }

        /// The number of bitmaps in the table.
        public var count: Int { info.count }
    }
}
