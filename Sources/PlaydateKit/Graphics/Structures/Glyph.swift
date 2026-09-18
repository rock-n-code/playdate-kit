internal import CPlaydate

extension Graphics {
    /// A glyph in a font. Wraps `LCDFontGlyph`. Retains its font.
    public struct Glyph {
        let pointer: OpaquePointer
        let font: Font

        /// Kerning adjustment between `glyphCode` and `nextCode`.
        public func kerning(glyphCode: UInt32, nextCode: UInt32) -> Int {
            Int(gfx.pointee.getGlyphKerning.unsafelyUnwrapped(pointer, glyphCode, nextCode))
        }
    }
}
