internal import CPlaydate

/// The graphics API: drawing, bitmaps, fonts, tilemaps, and video.
public enum Graphics {}

/// `playdate->graphics`.
var gfx: UnsafePointer<playdate_graphics> { Playdate.graphicsAPI.unsafelyUnwrapped }

extension Graphics {
    // MARK: - Screen constants

    /// Screen width, in pixels (`LCD_COLUMNS`).
    public static let columns = 400
    /// Screen height, in pixels (`LCD_ROWS`).
    public static let rows = 240
    /// Framebuffer row stride, in bytes (`LCD_ROWSIZE`).
    public static let rowSize = 52

    // MARK: - Drawing state

    public static func clear(color: Color = .white) {
        color.withLCDColor { gfx.pointee.clear.unsafelyUnwrapped($0) }
    }

    /// Shown where the display is offset; clears dirty areas in the sprite system.
    public static func setBackgroundColor(_ color: SolidColor) {
        gfx.pointee.setBackgroundColor.unsafelyUnwrapped(color.cValue)
    }

    /// Applies to bitmaps, and so text. Returns the previous mode.
    @discardableResult
    public static func setDrawMode(_ mode: DrawMode) -> DrawMode {
        DrawMode(gfx.pointee.setDrawMode.unsafelyUnwrapped(mode.cValue))
    }

    /// Offsets subsequent drawing by (`dx`, `dy`) pixels; may be negative.
    public static func setDrawOffset(dx: Int, dy: Int) {
        gfx.pointee.setDrawOffset.unsafelyUnwrapped(Int32(dx), Int32(dy))
    }

    /// In world coordinates (translated by the draw offset). Cleared each update.
    public static func setClipRect(x: Int, y: Int, width: Int, height: Int) {
        gfx.pointee.setClipRect.unsafelyUnwrapped(Int32(x), Int32(y), Int32(width), Int32(height))
    }

    /// In world coordinates (translated by the draw offset). Cleared each update.
    public static func setClipRect(_ rect: Rect) {
        setClipRect(x: rect.left, y: rect.top, width: rect.width, height: rect.height)
    }

    /// In screen coordinates (ignoring the draw offset).
    public static func setScreenClipRect(x: Int, y: Int, width: Int, height: Int) {
        gfx.pointee.setScreenClipRect.unsafelyUnwrapped(Int32(x), Int32(y), Int32(width), Int32(height))
    }

    /// In screen coordinates (ignoring the draw offset).
    public static func setScreenClipRect(_ rect: Rect) {
        setScreenClipRect(x: rect.left, y: rect.top, width: rect.width, height: rect.height)
    }

    public static func clearClipRect() {
        gfx.pointee.clearClipRect.unsafelyUnwrapped()
    }

    public static func setLineCapStyle(_ style: LineCapStyle) {
        gfx.pointee.setLineCapStyle.unsafelyUnwrapped(style.cValue)
    }

    /// Pixels draw only where the stencil is white; `nil` clears it. A tiled stencil's
    /// width must be a multiple of 32. Not retained; keep it alive while set.
    public static func setStencil(_ image: Bitmap?, tile: Bool = false) {
        gfx.pointee.setStencilImage.unsafelyUnwrapped(image?.pointer, tile ? 1 : 0)
    }

    /// `nil` targets the display framebuffer. Not retained; keep `target` alive until
    /// the matching `popContext()`.
    public static func pushContext(_ target: Bitmap? = nil) {
        gfx.pointee.pushContext.unsafelyUnwrapped(target?.pointer)
    }

    /// Restores the previous context's drawing settings. No-op if none.
    public static func popContext() {
        gfx.pointee.popContext.unsafelyUnwrapped()
    }

    // MARK: - Shapes

    /// `width` is in pixels.
    public static func drawLine(x1: Int, y1: Int, x2: Int, y2: Int, width: Int, color: Color) {
        color.withLCDColor {
            gfx.pointee.drawLine.unsafelyUnwrapped(Int32(x1), Int32(y1), Int32(x2), Int32(y2), Int32(width), $0)
        }
    }

    public static func fillTriangle(x1: Int, y1: Int, x2: Int, y2: Int, x3: Int, y3: Int, color: Color) {
        color.withLCDColor {
            gfx.pointee.fillTriangle.unsafelyUnwrapped(Int32(x1), Int32(y1), Int32(x2), Int32(y2),
                                               Int32(x3), Int32(y3), $0)
        }
    }

    /// Stroked inside its frame.
    public static func drawRect(x: Int, y: Int, width: Int, height: Int, color: Color) {
        color.withLCDColor {
            gfx.pointee.drawRect.unsafelyUnwrapped(Int32(x), Int32(y), Int32(width), Int32(height), $0)
        }
    }

    /// Stroked inside its frame.
    public static func drawRect(_ rect: Rect, color: Color) {
        drawRect(x: rect.left, y: rect.top, width: rect.width, height: rect.height, color: color)
    }

    public static func fillRect(x: Int, y: Int, width: Int, height: Int, color: Color) {
        color.withLCDColor {
            gfx.pointee.fillRect.unsafelyUnwrapped(Int32(x), Int32(y), Int32(width), Int32(height), $0)
        }
    }

    public static func fillRect(_ rect: Rect, color: Color) {
        fillRect(x: rect.left, y: rect.top, width: rect.width, height: rect.height, color: color)
    }

    /// Stroked inside the rect. `radius` and `lineWidth` are in pixels.
    public static func drawRoundRect(x: Int, y: Int, width: Int, height: Int, radius: Int,
                                     lineWidth: Int, color: Color) {
        color.withLCDColor {
            gfx.pointee.drawRoundRect.unsafelyUnwrapped(Int32(x), Int32(y), Int32(width), Int32(height),
                                                Int32(radius), Int32(lineWidth), $0)
        }
    }

    /// Stroked inside the rect. `radius` and `lineWidth` are in pixels.
    public static func drawRoundRect(_ rect: Rect, radius: Int, lineWidth: Int, color: Color) {
        drawRoundRect(x: rect.left, y: rect.top, width: rect.width, height: rect.height,
                      radius: radius, lineWidth: lineWidth, color: color)
    }

    /// `radius` is in pixels.
    public static func fillRoundRect(x: Int, y: Int, width: Int, height: Int, radius: Int, color: Color) {
        color.withLCDColor {
            gfx.pointee.fillRoundRect.unsafelyUnwrapped(Int32(x), Int32(y), Int32(width), Int32(height),
                                                Int32(radius), $0)
        }
    }

    /// `radius` is in pixels.
    public static func fillRoundRect(_ rect: Rect, radius: Int, color: Color) {
        fillRoundRect(x: rect.left, y: rect.top, width: rect.width, height: rect.height,
                      radius: radius, color: color)
    }

    /// Stroked inside the rect. Differing angles draw only that arc (degrees clockwise
    /// from the top).
    public static func drawEllipse(x: Int, y: Int, width: Int, height: Int, lineWidth: Int,
                                   startAngle: Float = 0, endAngle: Float = 0, color: Color) {
        color.withLCDColor {
            gfx.pointee.drawEllipse.unsafelyUnwrapped(Int32(x), Int32(y), Int32(width), Int32(height),
                                              Int32(lineWidth), startAngle, endAngle, $0)
        }
    }

    /// Differing angles fill only that wedge (degrees clockwise from the top).
    public static func fillEllipse(x: Int, y: Int, width: Int, height: Int,
                                   startAngle: Float = 0, endAngle: Float = 0, color: Color) {
        color.withLCDColor {
            gfx.pointee.fillEllipse.unsafelyUnwrapped(Int32(x), Int32(y), Int32(width), Int32(height),
                                              startAngle, endAngle, $0)
        }
    }

    /// Stroked inside the rect. Differing angles draw only that arc (degrees clockwise
    /// from the top).
    public static func drawEllipse(in rect: Rect, lineWidth: Int,
                                   startAngle: Float = 0, endAngle: Float = 0, color: Color) {
        drawEllipse(x: rect.left, y: rect.top, width: rect.width, height: rect.height,
                    lineWidth: lineWidth, startAngle: startAngle, endAngle: endAngle, color: color)
    }

    /// Differing angles fill only that wedge (degrees clockwise from the top).
    public static func fillEllipse(in rect: Rect,
                                   startAngle: Float = 0, endAngle: Float = 0, color: Color) {
        fillEllipse(x: rect.left, y: rect.top, width: rect.width, height: rect.height,
                    startAngle: startAngle, endAngle: endAngle, color: color)
    }

    /// The last point connects back to the first.
    public static func fillPolygon(points: [(x: Int, y: Int)], color: Color,
                                   fillRule: PolygonFillRule = .nonZero) {
        withUnsafeTemporaryAllocation(of: Int32.self, capacity: points.count * 2) { coordinates in
            var index = 0
            for point in points {
                coordinates[index] = Int32(point.x)
                coordinates[index + 1] = Int32(point.y)
                index += 2
            }
            color.withLCDColor { cColor in
                gfx.pointee.fillPolygon.unsafelyUnwrapped(Int32(points.count), coordinates.baseAddress,
                                                  cColor, fillRule.cValue)
            }
        }
    }

    /// Slow in bulk; prefer bitmaps or framebuffer writes for many pixels.
    public static func setPixel(x: Int, y: Int, color: Color) {
        color.withLCDColor { gfx.pointee.setPixel.unsafelyUnwrapped(Int32(x), Int32(y), $0) }
    }

    /// The 8×8 pattern whose upper-left corner is (x, y) in `bitmap`.
    public static func colorToPattern(from bitmap: Bitmap, x: Int, y: Int) -> Pattern {
        var color: LCDColor = 0
        gfx.pointee.setColorToPattern.unsafelyUnwrapped(&color, bitmap.pointer, Int32(x), Int32(y))
        var pattern = Pattern(bytes: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        if let source = UnsafeRawPointer(bitPattern: UInt(color)) {
            withUnsafeMutableBytes(of: &pattern.bytes) { destination in
                destination.copyMemory(from: UnsafeRawBufferPointer(start: source, count: 16))
            }
        }
        return pattern
    }

    // MARK: - Text

    /// Uses the current font, or the system font if none is set. Returns the drawn width.
    @discardableResult
    public static func drawText(_ text: String, x: Int, y: Int) -> Int {
        text.withCString { cString in
            Int(gfx.pointee.drawText.unsafelyUnwrapped(cString, text.utf8.count,
                                                       kUTF8Encoding, Int32(x), Int32(y)))
        }
    }

    /// Wrapped and aligned inside the rect, with the current font.
    public static func drawText(_ text: String, x: Int, y: Int, width: Int, height: Int,
                                wrap: TextWrappingMode = .word, align: TextAlignment = .left) {
        text.withCString { cString in
            gfx.pointee.drawTextInRect.unsafelyUnwrapped(cString, text.utf8.count, kUTF8Encoding,
                                                         Int32(x), Int32(y), Int32(width), Int32(height),
                                                         wrap.cValue, align.cValue)
        }
    }

    /// Wrapped and aligned inside the rect, with the current font.
    public static func drawText(_ text: String, in rect: Rect,
                                wrap: TextWrappingMode = .word, align: TextAlignment = .left) {
        drawText(text, x: rect.left, y: rect.top, width: rect.width, height: rect.height,
                 wrap: wrap, align: align)
    }

    /// Not retained; keep `font` alive while set.
    public static func setFont(_ font: Font) {
        gfx.pointee.setFont.unsafelyUnwrapped(font.pointer)
    }

    /// Extra space between letters, in pixels.
    public static var textTracking: Int {
        get { Int(gfx.pointee.getTextTracking.unsafelyUnwrapped()) }
        set { gfx.pointee.setTextTracking.unsafelyUnwrapped(Int32(newValue)) }
    }

    /// Pixels added to the font's own leading for multi-line text.
    public static func setTextLeading(_ lineHeightAdjustment: Int) {
        gfx.pointee.setTextLeading.unsafelyUnwrapped(Int32(lineHeightAdjustment))
    }

    // MARK: - Framebuffer

    /// The working framebuffer: `rows` rows of `rowSize` bytes, 1 bit per pixel, MSB first,
    /// last 2 bytes of each row unused. The span is valid only inside `body`; `nil` if
    /// there is no framebuffer. Call `markUpdatedRows(from:to:)` after writing.
    public static func withFrame<Result, Failure: Error>(
        _ body: (inout MutableSpan<UInt8>) throws(Failure) -> Result
    ) throws(Failure) -> Result? {
        guard let frame = gfx.pointee.getFrame.unsafelyUnwrapped() else { return nil }
        var span = UnsafeMutableBufferPointer(start: frame, count: rows * rowSize).mutableSpan
        return try body(&span)
    }

    /// The last frame shown, laid out like `withFrame(_:)`. The span is valid only inside
    /// `body`; `nil` if there is no framebuffer.
    public static func withDisplayFrame<Result, Failure: Error>(
        _ body: (Span<UInt8>) throws(Failure) -> Result
    ) throws(Failure) -> Result? {
        guard let frame = gfx.pointee.getDisplayFrame.unsafelyUnwrapped() else { return nil }
        return try body(UnsafeBufferPointer(start: frame, count: rows * rowSize).span)
    }

    /// Simulator only: white pixels overlay the display in translucent red. `nil` on device.
    public static var debugBitmap: Bitmap? {
        guard let getDebugBitmap = gfx.pointee.getDebugBitmap,
              let pointer = getDebugBitmap() else { return nil }
        return Bitmap(pointer: pointer, isOwned: false)
    }

    /// Not a copy; owned by the system.
    public static var displayBufferBitmap: Bitmap? {
        guard let pointer = gfx.pointee.getDisplayBufferBitmap.unsafelyUnwrapped() else { return nil }
        return Bitmap(pointer: pointer, isOwned: false)
    }

    public static func copyFrameBufferBitmap() -> Bitmap? {
        guard let pointer = gfx.pointee.copyFrameBufferBitmap.unsafelyUnwrapped() else { return nil }
        return Bitmap(pointer: pointer, isOwned: true)
    }

    /// Marks rows `start`...`end` (inclusive) as changed by direct framebuffer writes.
    public static func markUpdatedRows(from start: Int, to end: Int) {
        gfx.pointee.markUpdatedRows.unsafelyUnwrapped(Int32(start), Int32(end))
    }

    /// Flushes the framebuffer. The system does this after each update.
    public static func display() {
        gfx.pointee.display.unsafelyUnwrapped()
    }
}
