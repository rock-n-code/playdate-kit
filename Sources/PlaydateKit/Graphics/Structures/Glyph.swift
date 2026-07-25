internal import CPlaydate

extension Graphics {
    /// A single glyph within a font. Wraps `LCDFontGlyph`.
    /// Keep the font alive while using its glyphs.
    public struct Glyph {
        let pointer: OpaquePointer
        let font: Font

        /// The kerning adjustment between this glyph and the next character.
        public func kerning(glyphCode: UInt32, nextCode: UInt32) -> Int {
            Int(gfx.pointee.getGlyphKerning.unsafelyUnwrapped(pointer, glyphCode, nextCode))
        }
    }
}
