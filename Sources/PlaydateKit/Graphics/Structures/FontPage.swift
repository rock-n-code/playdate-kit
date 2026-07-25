internal import CPlaydate

extension Graphics {
    /// A page of glyphs within a font. Wraps `LCDFontPage`.
    /// Keep the font alive while using its pages.
    public struct FontPage {
        let pointer: OpaquePointer
        let font: Font

        /// The glyph for `codepoint` within this page, with its bitmap and advance.
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
