//
//  GraphicsFont.swift
//  Font, FontPage, and Glyph wrappers around LCDFont / LCDFontPage / LCDFontGlyph.
//

internal import CPlaydate

extension Playdate.Graphics {
    /// A font loaded from a .pft file. Wraps `LCDFont`.
    public final class Font {
        let pointer: OpaquePointer
        /// Fonts created from in-memory data reference that data; it is kept
        /// alive here.
        private let retainedData: UnsafeRawPointer?

        init(pointer: OpaquePointer, retainedData: UnsafeRawPointer? = nil) {
            self.pointer = pointer
            self.retainedData = retainedData
        }

        /// Loads a font from a file.
        public convenience init(path: String) throws(Playdate.Error) {
            var error: UnsafePointer<CChar>?
            let pointer = path.withPlaydateCString { gfx.loadFont.unsafelyUnwrapped($0, &error) }
            guard let pointer else { throw Playdate.Error(cString: error) }
            self.init(pointer: pointer)
        }

        /// Creates a font from the contents of a .pft file already in memory.
        /// The bytes are copied and retained for the font's lifetime.
        public convenience init?(data: UnsafeRawBufferPointer, wide: Bool = false) {
            let copy = UnsafeMutableRawPointer.allocate(byteCount: data.count, alignment: 4)
            copy.copyMemory(from: data.baseAddress.unsafelyUnwrapped, byteCount: data.count)
            let fontData = OpaquePointer(copy)
            guard let pointer = gfx.makeFontFromData.unsafelyUnwrapped(
                fontData, wide ? 1 : 0, Int32(data.count)) else {
                copy.deallocate()
                return nil
            }
            self.init(pointer: pointer, retainedData: UnsafeRawPointer(copy))
        }

        deinit {
            // Per the C API docs, fonts are freed with the system allocator.
            Playdate.System.systemFree(UnsafeMutableRawPointer(pointer))
            retainedData?.deallocate()
        }

        /// The font's glyph height in pixels.
        public var height: Int {
            Int(gfx.getFontHeight.unsafelyUnwrapped(pointer))
        }

        /// The width of `text` when drawn with this font.
        public func textWidth(_ text: String, tracking: Int = 0) -> Int {
            let utf8 = ContiguousArray(text.utf8)
            return utf8.withUnsafeBufferPointer { buffer in
                Int(gfx.getTextWidth.unsafelyUnwrapped(pointer, buffer.baseAddress, buffer.count,
                                                       kUTF8Encoding, Int32(tracking)))
            }
        }

        /// The height of `text` when wrapped to `maxWidth` with this font.
        public func textHeight(_ text: String, maxWidth: Int, wrap: TextWrappingMode = .word,
                               tracking: Int = 0, extraLeading: Int = 0) -> Int {
            let utf8 = ContiguousArray(text.utf8)
            return utf8.withUnsafeBufferPointer { buffer in
                Int(gfx.getTextHeightForMaxWidth.unsafelyUnwrapped(
                    pointer, buffer.baseAddress, buffer.count, Int32(maxWidth), kUTF8Encoding,
                    wrap.cValue, Int32(tracking), Int32(extraLeading)))
            }
        }

        /// The page containing glyph data for the character `codepoint`
        /// belongs to. The page references data owned by the font.
        public func page(for codepoint: UInt32) -> FontPage? {
            guard let page = gfx.getFontPage.unsafelyUnwrapped(pointer, codepoint) else { return nil }
            return FontPage(pointer: page, font: self)
        }

        /// The glyph for `codepoint`, with its bitmap and advance.
        /// The bitmap references data owned by the font.
        public func glyph(for codepoint: UInt32) -> (glyph: Glyph, bitmap: Bitmap?, advance: Int)? {
            var bitmap: OpaquePointer?
            var advance: Int32 = 0
            guard let glyph = gfx.getFontGlyph.unsafelyUnwrapped(pointer, codepoint, &bitmap, &advance) else {
                return nil
            }
            return (Glyph(pointer: glyph, font: self),
                    bitmap.map { Bitmap(pointer: $0, isOwned: false) },
                    Int(advance))
        }
    }

    /// A page of glyphs within a font. Wraps `LCDFontPage`.
    /// Keep the font alive while using its pages.
    public struct FontPage {
        let pointer: OpaquePointer
        let font: Font

        /// The glyph for `codepoint` within this page, with its bitmap and advance.
        public func glyph(for codepoint: UInt32) -> (glyph: Glyph, bitmap: Bitmap?, advance: Int)? {
            var bitmap: OpaquePointer?
            var advance: Int32 = 0
            guard let glyph = gfx.getPageGlyph.unsafelyUnwrapped(pointer, codepoint, &bitmap, &advance) else {
                return nil
            }
            return (Glyph(pointer: glyph, font: font),
                    bitmap.map { Bitmap(pointer: $0, isOwned: false) },
                    Int(advance))
        }
    }

    /// A single glyph within a font. Wraps `LCDFontGlyph`.
    /// Keep the font alive while using its glyphs.
    public struct Glyph {
        let pointer: OpaquePointer
        let font: Font

        /// The kerning adjustment between this glyph and the next character.
        public func kerning(glyphCode: UInt32, nextCode: UInt32) -> Int {
            Int(gfx.getGlyphKerning.unsafelyUnwrapped(pointer, glyphCode, nextCode))
        }
    }
}
