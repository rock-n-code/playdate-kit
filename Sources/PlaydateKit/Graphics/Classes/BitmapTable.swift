internal import CPlaydate

extension Graphics {
    /// An image table. Wraps `LCDBitmapTable`. Its bitmaps are borrowed and invalid once
    /// the table is freed.
    public final class BitmapTable {
        let pointer: OpaquePointer

        init(pointer: OpaquePointer) {
            self.pointer = pointer
        }

        /// Room for `count` bitmaps of `width` × `height` pixels.
        public convenience init(count: Int, width: Int, height: Int) {
            let pointer = gfx.pointee.newBitmapTable.unsafelyUnwrapped(Int32(count), Int32(width), Int32(height))
            self.init(pointer: pointer.unsafelyUnwrapped)
        }

        public convenience init(path: String) throws(PlaydateError) {
            var error: UnsafePointer<CChar>?
            let pointer = path.withCString { gfx.pointee.loadBitmapTable.unsafelyUnwrapped($0, &error) }
            guard let pointer else { throw PlaydateError(cString: error) }
            self.init(pointer: pointer)
        }

        deinit {
            gfx.pointee.freeBitmapTable.unsafelyUnwrapped(pointer)
        }

        public func load(path: String) throws(PlaydateError) {
            var error: UnsafePointer<CChar>?
            path.withCString { gfx.pointee.loadIntoBitmapTable.unsafelyUnwrapped($0, pointer, &error) }
            if let error { throw PlaydateError(cString: error) }
        }

        /// `nil` if out of range.
        public func bitmap(at index: Int) -> Bitmap? {
            guard let bitmap = gfx.pointee.getTableBitmap.unsafelyUnwrapped(pointer, Int32(index)) else {
                return nil
            }
            return Bitmap(pointer: bitmap, isOwned: false)
        }

        /// Bitmap count and cells across the source image.
        public var info: (count: Int, cellsWide: Int) {
            var count: Int32 = 0, width: Int32 = 0
            gfx.pointee.getBitmapTableInfo.unsafelyUnwrapped(pointer, &count, &width)
            return (Int(count), Int(width))
        }

        public var count: Int { info.count }
    }
}

extension Graphics.BitmapTable: RandomAccessCollection {
    public var startIndex: Int { 0 }
    public var endIndex: Int { count }

    /// Traps if out of range.
    public subscript(position: Int) -> Graphics.Bitmap {
        guard let bitmap = bitmap(at: position) else {
            preconditionFailure("bitmap table index out of range")
        }
        return bitmap
    }
}
