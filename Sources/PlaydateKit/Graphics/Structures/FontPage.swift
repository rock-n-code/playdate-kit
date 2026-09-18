internal import CPlaydate

extension Graphics {
    /// A page of 256 glyphs in a font. Wraps `LCDFontPage`. Retains its font.
    public struct FontPage {
        let pointer: OpaquePointer
        let font: Font

        /// `nil` if `codepoint` isn't on this page. The bitmap doesn't retain the font.
        public func glyph(for codepoint: UInt32) -> (glyph: Glyph, bitmap: Bitmap?, advance: Int)? {
            var bitmap: OpaquePointer?
            var advance: Int32 = 0
            guard let glyph = gfx.pointee.getPageGlyph.unsafelyUnwrapped(pointer, codepoint, &bitmap, &advance) else {
                return nil
            }
            return (Glyph(pointer: glyph, font: font),
                    bitmap.map { Bitmap(pointer: $0, isOwned: false) },
                    Int(advance))
        }
    }
}
