//
//  Graphics.swift
//  Wraps `playdate->graphics` (pd_api_gfx.h): drawing state, shapes, text,
//  and raw framebuffer access. Bitmap, font, tilemap, and video wrappers live
//  in their own files.
//

internal import CPlaydate

extension Playdate {
    /// The graphics API: drawing, bitmaps, fonts, tilemaps, and video.
    public enum Graphics {}
}

var gfx: playdate_graphics { Playdate.api.graphics.pointee }

extension Playdate.Graphics {
    // MARK: - Screen constants

    /// The width of the screen in pixels (`LCD_COLUMNS`).
    public static let columns = 400
    /// The height of the screen in pixels (`LCD_ROWS`).
    public static let rows = 240
    /// The stride of a framebuffer row in bytes (`LCD_ROWSIZE`).
    public static let rowSize = 52

    // MARK: - Types

    /// An 8×8 two-color pattern: 8 rows of image data followed by 8 rows of mask.
    public struct Pattern: Sendable {
        public var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                           UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

        public init(bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)) {
            self.bytes = bytes
        }

        /// Creates an opaque pattern from 8 rows of image data.
        public init(rows r: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)) {
            bytes = (r.0, r.1, r.2, r.3, r.4, r.5, r.6, r.7,
                     0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff)
        }
    }

    /// A drawing color: solid or an 8×8 pattern.
    public enum Color: Sendable {
        case black
        case white
        case clear
        case xor
        case pattern(Pattern)

        /// Materializes the `LCDColor` for the duration of `body`. Pattern
        /// colors pass a pointer to a temporary, so the value must not be
        /// stored beyond the call.
        func withLCDColor<Result>(_ body: (LCDColor) -> Result) -> Result {
            switch self {
            case .black: return body(LCDColor(kColorBlack.rawValue))
            case .white: return body(LCDColor(kColorWhite.rawValue))
            case .clear: return body(LCDColor(kColorClear.rawValue))
            case .xor: return body(LCDColor(kColorXOR.rawValue))
            case .pattern(let pattern):
                return withUnsafeBytes(of: pattern.bytes) { buffer in
                    body(LCDColor(UInt(bitPattern: buffer.baseAddress)))
                }
            }
        }
    }

    /// A solid color, for APIs that cannot take a pattern.
    public enum SolidColor: UInt32, Sendable {
        case black = 0
        case white = 1
        case clear = 2
        case xor = 3

        init(_ color: LCDSolidColor) { self = SolidColor(rawValue: color.rawValue) ?? .clear }
        var cValue: LCDSolidColor { LCDSolidColor(rawValue) }
    }

    /// How source pixels combine with the destination when drawing.
    public enum DrawMode: UInt32, Sendable {
        case copy = 0
        case whiteTransparent = 1
        case blackTransparent = 2
        case fillWhite = 3
        case fillBlack = 4
        case xor = 5
        case nxor = 6
        case inverted = 7

        init(_ mode: LCDBitmapDrawMode) { self = DrawMode(rawValue: mode.rawValue) ?? .copy }
        var cValue: LCDBitmapDrawMode { LCDBitmapDrawMode(rawValue) }
    }

    /// Mirroring applied when drawing a bitmap.
    public enum BitmapFlip: UInt32, Sendable {
        case unflipped = 0
        case flippedX = 1
        case flippedY = 2
        case flippedXY = 3

        init(_ flip: LCDBitmapFlip) { self = BitmapFlip(rawValue: flip.rawValue) ?? .unflipped }
        var cValue: LCDBitmapFlip { LCDBitmapFlip(rawValue) }
    }

    /// The end cap style used when drawing lines.
    public enum LineCapStyle: UInt32, Sendable {
        case butt = 0
        case square = 1
        case round = 2

        var cValue: LCDLineCapStyle { LCDLineCapStyle(rawValue) }
    }

    /// The encoding of text passed to the text functions.
    public enum StringEncoding: UInt32, Sendable {
        case ascii = 0
        case utf8 = 1
        case utf16LittleEndian = 2

        var cValue: PDStringEncoding { PDStringEncoding(rawValue) }
    }

    /// The winding rule used by `fillPolygon`.
    public enum PolygonFillRule: UInt32, Sendable {
        case nonZero = 0
        case evenOdd = 1

        var cValue: LCDPolygonFillRule { LCDPolygonFillRule(rawValue) }
    }

    /// How text wraps in `drawText(in:)`.
    public enum TextWrappingMode: UInt32, Sendable {
        case clip = 0
        case character = 1
        case word = 2

        var cValue: PDTextWrappingMode { PDTextWrappingMode(rawValue) }
    }

    /// Horizontal alignment for `drawText(in:)`.
    public enum TextAlignment: UInt32, Sendable {
        case left = 0
        case center = 1
        case right = 2

        var cValue: PDTextAlignment { PDTextAlignment(rawValue) }
    }

    /// An integer rectangle mirroring `LCDRect`. `right` and `bottom` are
    /// not inclusive.
    public struct Rect: Sendable {
        public var left: Int
        public var right: Int
        public var top: Int
        public var bottom: Int

        public init(left: Int, right: Int, top: Int, bottom: Int) {
            self.left = left
            self.right = right
            self.top = top
            self.bottom = bottom
        }

        public init(x: Int, y: Int, width: Int, height: Int) {
            self.init(left: x, right: x + width, top: y, bottom: y + height)
        }

        init(_ rect: LCDRect) {
            self.init(left: Int(rect.left), right: Int(rect.right),
                      top: Int(rect.top), bottom: Int(rect.bottom))
        }

        var cValue: LCDRect {
            LCDRect(left: Int32(left), right: Int32(right),
                    top: Int32(top), bottom: Int32(bottom))
        }

        public func translated(dx: Int, dy: Int) -> Rect {
            Rect(left: left + dx, right: right + dx, top: top + dy, bottom: bottom + dy)
        }
    }

    // MARK: - Drawing state

    /// Clears the entire display, filling it with `color`.
    public static func clear(color: Color = .white) {
        color.withLCDColor { gfx.clear.unsafelyUnwrapped($0) }
    }

    /// Sets the background color shown when the display is offset or for
    /// clear pixels in drawn images.
    public static func setBackgroundColor(_ color: SolidColor) {
        gfx.setBackgroundColor.unsafelyUnwrapped(color.cValue)
    }

    /// Sets the mode that determines how source pixels combine with the
    /// destination. Returns the previous mode.
    @discardableResult
    public static func setDrawMode(_ mode: DrawMode) -> DrawMode {
        DrawMode(gfx.setDrawMode.unsafelyUnwrapped(mode.cValue))
    }

    /// Offsets all subsequent drawing by (dx, dy).
    public static func setDrawOffset(dx: Int, dy: Int) {
        gfx.setDrawOffset.unsafelyUnwrapped(Int32(dx), Int32(dy))
    }

    /// Sets the clip rect in world coordinates (affected by the draw offset).
    public static func setClipRect(x: Int, y: Int, width: Int, height: Int) {
        gfx.setClipRect.unsafelyUnwrapped(Int32(x), Int32(y), Int32(width), Int32(height))
    }

    /// Sets the clip rect in screen coordinates (unaffected by the draw offset).
    public static func setScreenClipRect(x: Int, y: Int, width: Int, height: Int) {
        gfx.setScreenClipRect.unsafelyUnwrapped(Int32(x), Int32(y), Int32(width), Int32(height))
    }

    public static func clearClipRect() {
        gfx.clearClipRect.unsafelyUnwrapped()
    }

    public static func setLineCapStyle(_ style: LineCapStyle) {
        gfx.setLineCapStyle.unsafelyUnwrapped(style.cValue)
    }

    /// Sets the stencil applied to subsequent drawing. If `tile` is `true`
    /// the stencil image is tiled, and its width must be a multiple of 32.
    /// Pass `nil` to clear the stencil.
    public static func setStencil(_ image: Bitmap?, tile: Bool = false) {
        gfx.setStencilImage.unsafelyUnwrapped(image?.pointer, tile ? 1 : 0)
    }

    /// Pushes a new drawing context targeting `target`, or the display if
    /// `target` is `nil`.
    public static func pushContext(_ target: Bitmap? = nil) {
        gfx.pushContext.unsafelyUnwrapped(target?.pointer)
    }

    public static func popContext() {
        gfx.popContext.unsafelyUnwrapped()
    }

    // MARK: - Shapes

    public static func drawLine(x1: Int, y1: Int, x2: Int, y2: Int, width: Int, color: Color) {
        color.withLCDColor {
            gfx.drawLine.unsafelyUnwrapped(Int32(x1), Int32(y1), Int32(x2), Int32(y2), Int32(width), $0)
        }
    }

    public static func fillTriangle(x1: Int, y1: Int, x2: Int, y2: Int, x3: Int, y3: Int, color: Color) {
        color.withLCDColor {
            gfx.fillTriangle.unsafelyUnwrapped(Int32(x1), Int32(y1), Int32(x2), Int32(y2),
                                               Int32(x3), Int32(y3), $0)
        }
    }

    public static func drawRect(x: Int, y: Int, width: Int, height: Int, color: Color) {
        color.withLCDColor {
            gfx.drawRect.unsafelyUnwrapped(Int32(x), Int32(y), Int32(width), Int32(height), $0)
        }
    }

    public static func fillRect(x: Int, y: Int, width: Int, height: Int, color: Color) {
        color.withLCDColor {
            gfx.fillRect.unsafelyUnwrapped(Int32(x), Int32(y), Int32(width), Int32(height), $0)
        }
    }

    public static func drawRoundRect(x: Int, y: Int, width: Int, height: Int, radius: Int,
                                     lineWidth: Int, color: Color) {
        color.withLCDColor {
            gfx.drawRoundRect.unsafelyUnwrapped(Int32(x), Int32(y), Int32(width), Int32(height),
                                                Int32(radius), Int32(lineWidth), $0)
        }
    }

    public static func fillRoundRect(x: Int, y: Int, width: Int, height: Int, radius: Int, color: Color) {
        color.withLCDColor {
            gfx.fillRoundRect.unsafelyUnwrapped(Int32(x), Int32(y), Int32(width), Int32(height),
                                                Int32(radius), $0)
        }
    }

    /// Draws an ellipse stroked inside the rect. If the angles differ, draws
    /// an arc from `startAngle` to `endAngle` (clockwise degrees, 0 at top).
    public static func drawEllipse(x: Int, y: Int, width: Int, height: Int, lineWidth: Int,
                                   startAngle: Float = 0, endAngle: Float = 0, color: Color) {
        color.withLCDColor {
            gfx.drawEllipse.unsafelyUnwrapped(Int32(x), Int32(y), Int32(width), Int32(height),
                                              Int32(lineWidth), startAngle, endAngle, $0)
        }
    }

    public static func fillEllipse(x: Int, y: Int, width: Int, height: Int,
                                   startAngle: Float = 0, endAngle: Float = 0, color: Color) {
        color.withLCDColor {
            gfx.fillEllipse.unsafelyUnwrapped(Int32(x), Int32(y), Int32(width), Int32(height),
                                              startAngle, endAngle, $0)
        }
    }

    /// Fills the polygon described by the points, connecting the last point
    /// back to the first.
    public static func fillPolygon(points: [(x: Int, y: Int)], color: Color,
                                   fillRule: PolygonFillRule = .nonZero) {
        var coordinates = [Int32]()
        coordinates.reserveCapacity(points.count * 2)
        for point in points {
            coordinates.append(Int32(point.x))
            coordinates.append(Int32(point.y))
        }
        color.withLCDColor { cColor in
            coordinates.withUnsafeMutableBufferPointer { buffer in
                gfx.fillPolygon.unsafelyUnwrapped(Int32(points.count), buffer.baseAddress,
                                                  cColor, fillRule.cValue)
            }
        }
    }

    /// Sets the pixel at (x, y) in the current drawing context.
    public static func setPixel(x: Int, y: Int, color: Color) {
        color.withLCDColor { gfx.setPixel.unsafelyUnwrapped(Int32(x), Int32(y), $0) }
    }

    /// Reads an 8×8 pattern from the bitmap starting at (x, y).
    public static func colorToPattern(from bitmap: Bitmap, x: Int, y: Int) -> Pattern {
        var color: LCDColor = 0
        gfx.setColorToPattern.unsafelyUnwrapped(&color, bitmap.pointer, Int32(x), Int32(y))
        var pattern = Pattern(bytes: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        if let source = UnsafeRawPointer(bitPattern: UInt(color)) {
            withUnsafeMutableBytes(of: &pattern.bytes) { destination in
                destination.copyMemory(from: UnsafeRawBufferPointer(start: source, count: 16))
            }
        }
        return pattern
    }

    // MARK: - Text

    /// Draws `text` at (x, y) using the current font. Returns the drawn width.
    @discardableResult
    public static func drawText(_ text: String, x: Int, y: Int) -> Int {
        let utf8 = ContiguousArray(text.utf8)
        return utf8.withUnsafeBufferPointer { buffer in
            Int(gfx.drawText.unsafelyUnwrapped(buffer.baseAddress, buffer.count,
                                               kUTF8Encoding, Int32(x), Int32(y)))
        }
    }

    /// Draws `text` wrapped and aligned inside the given rectangle.
    public static func drawText(_ text: String, x: Int, y: Int, width: Int, height: Int,
                                wrap: TextWrappingMode = .word, align: TextAlignment = .left) {
        let utf8 = ContiguousArray(text.utf8)
        utf8.withUnsafeBufferPointer { buffer in
            gfx.drawTextInRect.unsafelyUnwrapped(buffer.baseAddress, buffer.count, kUTF8Encoding,
                                                 Int32(x), Int32(y), Int32(width), Int32(height),
                                                 wrap.cValue, align.cValue)
        }
    }

    /// Sets the font used by subsequent text drawing.
    public static func setFont(_ font: Font) {
        gfx.setFont.unsafelyUnwrapped(font.pointer)
    }

    /// Extra space added between letters, in pixels.
    public static func setTextTracking(_ tracking: Int) {
        gfx.setTextTracking.unsafelyUnwrapped(Int32(tracking))
    }

    public static var textTracking: Int {
        Int(gfx.getTextTracking.unsafelyUnwrapped())
    }

    /// Adjusts the line height used when drawing multi-line text.
    public static func setTextLeading(_ lineHeightAdjustment: Int) {
        gfx.setTextLeading.unsafelyUnwrapped(Int32(lineHeightAdjustment))
    }

    // MARK: - Framebuffer

    /// The current working framebuffer. Rows are `rowSize` bytes.
    /// Call `markUpdatedRows(from:to:)` after writing directly.
    public static var frame: UnsafeMutablePointer<UInt8>? {
        gfx.getFrame.unsafelyUnwrapped()
    }

    /// The framebuffer currently shown on the display. Rows are `rowSize` bytes.
    public static var displayFrame: UnsafeMutablePointer<UInt8>? {
        gfx.getDisplayFrame.unsafelyUnwrapped()
    }

    /// A bitmap view of the display framebuffer. Simulator only; `nil` on device.
    public static var debugBitmap: Bitmap? {
        guard let getDebugBitmap = gfx.getDebugBitmap,
              let pointer = getDebugBitmap() else { return nil }
        return Bitmap(pointer: pointer, isOwned: false)
    }

    /// A bitmap referencing the display framebuffer (not a copy).
    public static var displayBufferBitmap: Bitmap? {
        guard let pointer = gfx.getDisplayBufferBitmap.unsafelyUnwrapped() else { return nil }
        return Bitmap(pointer: pointer, isOwned: false)
    }

    /// A copy of the working framebuffer as a new bitmap.
    public static func copyFrameBufferBitmap() -> Bitmap? {
        guard let pointer = gfx.copyFrameBufferBitmap.unsafelyUnwrapped() else { return nil }
        return Bitmap(pointer: pointer, isOwned: true)
    }

    /// Tells the system which rows (inclusive) were changed by direct
    /// framebuffer writes and need redisplay.
    public static func markUpdatedRows(from start: Int, to end: Int) {
        gfx.markUpdatedRows.unsafelyUnwrapped(Int32(start), Int32(end))
    }

    /// Manually flushes the framebuffer to the display. Only needed when
    /// drawing outside the normal update cycle.
    public static func display() {
        gfx.display.unsafelyUnwrapped()
    }
}
