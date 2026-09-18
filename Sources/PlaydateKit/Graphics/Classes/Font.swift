internal import CPlaydate

extension Graphics {
    /// A .pft bitmap font. Wraps `LCDFont`. Glyph bitmaps are borrowed and don't retain
    /// the font; keep it alive while using them.
    public final class Font {
        let pointer: OpaquePointer
        /// `makeFontFromData` doesn't copy its buffer, so it lives as long as the font.
        private let retainedData: UnsafeRawPointer?

        init(pointer: OpaquePointer, retainedData: UnsafeRawPointer? = nil) {
            self.pointer = pointer
            self.retainedData = retainedData
        }

        public convenience init(path: String) throws(PlaydateError) {
            var error: UnsafePointer<CChar>?
            let pointer = path.withCString { gfx.pointee.loadFont.unsafelyUnwrapped($0, &error) }
            guard let pointer else { throw PlaydateError(cString: error) }
            self.init(pointer: pointer)
        }

        /// `data`: an uncompressed .pft file minus its 16-byte header; copied for the font's
        /// lifetime. `wide` must match the header flag for glyphs above U+1FFFF.
        public convenience init?(data: Span<UInt8>, wide: Bool = false) {
            let copy = UnsafeMutableRawPointer.allocate(byteCount: data.count, alignment: 4)
            data.withUnsafeBytes { bytes in
                copy.copyMemory(from: bytes.baseAddress.unsafelyUnwrapped, byteCount: bytes.count)
            }
            let fontData = OpaquePointer(copy)
            guard let pointer = gfx.pointee.makeFontFromData.unsafelyUnwrapped(
                fontData, wide ? 1 : 0, Int32(data.count)) else {
                copy.deallocate()
                return nil
            }
            self.init(pointer: pointer, retainedData: UnsafeRawPointer(copy))
        }

        deinit {
            // There is no freeFont; fonts are released with `realloc(font, 0)`.
            System.systemFree(UnsafeMutableRawPointer(pointer))
            retainedData?.deallocate()
        }

        /// Height, in pixels.
        public var height: Int {
            Int(gfx.pointee.getFontHeight.unsafelyUnwrapped(pointer))
        }

        /// Width in pixels; `tracking` is pixels between characters.
        public func textWidth(_ text: String, tracking: Int = 0) -> Int {
            text.withCString { cString in
                Int(gfx.pointee.getTextWidth.unsafelyUnwrapped(pointer, cString, text.utf8.count,
                                                               kUTF8Encoding, Int32(tracking)))
            }
        }

        /// Height in pixels of `text` wrapped to `maxWidth` pixels.
        public func textHeight(_ text: String, maxWidth: Int, wrap: TextWrappingMode = .word,
                               tracking: Int = 0, extraLeading: Int = 0) -> Int {
            text.withCString { cString in
                Int(gfx.pointee.getTextHeightForMaxWidth.unsafelyUnwrapped(
                    pointer, cString, text.utf8.count, Int32(maxWidth), kUTF8Encoding,
                    wrap.cValue, Int32(tracking), Int32(extraLeading)))
            }
        }

        /// `nil` if none. Codepoints differing only in their low 8 bits share a page.
        public func page(for codepoint: UInt32) -> FontPage? {
            guard let page = gfx.pointee.getFontPage.unsafelyUnwrapped(pointer, codepoint) else { return nil }
            return FontPage(pointer: page, font: self)
        }

        /// `nil` if the font has no glyph for `codepoint`.
        public func glyph(for codepoint: UInt32) -> (glyph: Glyph, bitmap: Bitmap?, advance: Int)? {
            var bitmap: OpaquePointer?
            var advance: Int32 = 0
            guard let glyph = gfx.pointee.getFontGlyph.unsafelyUnwrapped(pointer, codepoint, &bitmap, &advance) else {
                return nil
            }
            return (Glyph(pointer: glyph, font: self),
                    bitmap.map { Bitmap(pointer: $0, isOwned: false) },
                    Int(advance))
        }
    }
}
