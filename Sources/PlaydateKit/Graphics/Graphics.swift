internal import CPlaydate

/// The graphics API: drawing, bitmaps, fonts, tilemaps, and video.
public enum Graphics {}

/// The cached `playdate->graphics` C API table.
var gfx: UnsafePointer<playdate_graphics> { Playdate.graphicsAPI.unsafelyUnwrapped }

extension Graphics {
    // MARK: - Screen constants

    /// The width of the screen in pixels (`LCD_COLUMNS`).
    public static let columns = 400
    /// The height of the screen in pixels (`LCD_ROWS`).
    public static let rows = 240
    /// The stride of a framebuffer row in bytes (`LCD_ROWSIZE`).
    public static let rowSize = 52

    // MARK: - Drawing state

    /// Clears the entire display, filling it with `color`.
    public static func clear(color: Color = .white) {
        color.withLCDColor { gfx.pointee.clear.unsafelyUnwrapped($0) }
    }

    /// Sets the background color shown when the display is offset or for
    /// clear pixels in drawn images.
    public static func setBackgroundColor(_ color: SolidColor) {
        gfx.pointee.setBackgroundColor.unsafelyUnwrapped(color.cValue)
    }

    /// Sets the mode that determines how source pixels combine with the
    /// destination. Returns the previous mode.
    @discardableResult
    public static func setDrawMode(_ mode: DrawMode) -> DrawMode {
        DrawMode(gfx.pointee.setDrawMode.unsafelyUnwrapped(mode.cValue))
    }

    /// Offsets all subsequent drawing by (dx, dy).
    public static func setDrawOffset(dx: Int, dy: Int) {
        gfx.pointee.setDrawOffset.unsafelyUnwrapped(Int32(dx), Int32(dy))
    }

    /// Sets the clip rect in world coordinates (affected by the draw offset).
    public static func setClipRect(x: Int, y: Int, width: Int, height: Int) {
        gfx.pointee.setClipRect.unsafelyUnwrapped(Int32(x), Int32(y), Int32(width), Int32(height))
    }

    /// Sets the clip rect in world coordinates (affected by the draw offset).
    public static func setClipRect(_ rect: Rect) {
        setClipRect(x: rect.left, y: rect.top, width: rect.width, height: rect.height)
    }

    /// Sets the clip rect in screen coordinates (unaffected by the draw offset).
    public static func setScreenClipRect(x: Int, y: Int, width: Int, height: Int) {
        gfx.pointee.setScreenClipRect.unsafelyUnwrapped(Int32(x), Int32(y), Int32(width), Int32(height))
    }

    /// Sets the clip rect in screen coordinates (unaffected by the draw offset).
    public static func setScreenClipRect(_ rect: Rect) {
        setScreenClipRect(x: rect.left, y: rect.top, width: rect.width, height: rect.height)
    }

    /// Clears the current clip rect.
    public static func clearClipRect() {
        gfx.pointee.clearClipRect.unsafelyUnwrapped()
    }

    /// Sets the end cap style used by subsequent line drawing.
    public static func setLineCapStyle(_ style: LineCapStyle) {
        gfx.pointee.setLineCapStyle.unsafelyUnwrapped(style.cValue)
    }

    /// Sets the stencil applied to subsequent drawing. If `tile` is `true`
    /// the stencil image is tiled, and its width must be a multiple of 32.
    /// Pass `nil` to clear the stencil.
    public static func setStencil(_ image: Bitmap?, tile: Bool = false) {
        gfx.pointee.setStencilImage.unsafelyUnwrapped(image?.pointer, tile ? 1 : 0)
    }

    /// Pushes a new drawing context targeting `target`, or the display if
    /// `target` is `nil`.
    public static func pushContext(_ target: Bitmap? = nil) {
        gfx.pointee.pushContext.unsafelyUnwrapped(target?.pointer)
    }

    /// Pops the top drawing context off the stack.
    public static func popContext() {
        gfx.pointee.popContext.unsafelyUnwrapped()
    }

    // MARK: - Shapes

    /// Draws a line from (x1, y1) to (x2, y2) with the given stroke width.
    public static func drawLine(x1: Int, y1: Int, x2: Int, y2: Int, width: Int, color: Color) {
        color.withLCDColor {
            gfx.pointee.drawLine.unsafelyUnwrapped(Int32(x1), Int32(y1), Int32(x2), Int32(y2), Int32(width), $0)
        }
    }

    /// Fills the triangle with vertices (x1, y1), (x2, y2), and (x3, y3).
    public static func fillTriangle(x1: Int, y1: Int, x2: Int, y2: Int, x3: Int, y3: Int, color: Color) {
        color.withLCDColor {
            gfx.pointee.fillTriangle.unsafelyUnwrapped(Int32(x1), Int32(y1), Int32(x2), Int32(y2),
                                               Int32(x3), Int32(y3), $0)
        }
    }

    /// Draws the outline of a rectangle, stroked inside its frame.
    public static func drawRect(x: Int, y: Int, width: Int, height: Int, color: Color) {
        color.withLCDColor {
            gfx.pointee.drawRect.unsafelyUnwrapped(Int32(x), Int32(y), Int32(width), Int32(height), $0)
        }
    }

    /// Draws the outline of a rectangle, stroked inside its frame.
    public static func drawRect(_ rect: Rect, color: Color) {
        drawRect(x: rect.left, y: rect.top, width: rect.width, height: rect.height, color: color)
    }

    /// Fills the rectangle with `color`.
    public static func fillRect(x: Int, y: Int, width: Int, height: Int, color: Color) {
        color.withLCDColor {
            gfx.pointee.fillRect.unsafelyUnwrapped(Int32(x), Int32(y), Int32(width), Int32(height), $0)
        }
    }

    /// Fills the rectangle with `color`.
    public static func fillRect(_ rect: Rect, color: Color) {
        fillRect(x: rect.left, y: rect.top, width: rect.width, height: rect.height, color: color)
    }

    /// Draws the outline of a rectangle with rounded corners, stroked with
    /// `lineWidth`.
    public static func drawRoundRect(x: Int, y: Int, width: Int, height: Int, radius: Int,
                                     lineWidth: Int, color: Color) {
        color.withLCDColor {
            gfx.pointee.drawRoundRect.unsafelyUnwrapped(Int32(x), Int32(y), Int32(width), Int32(height),
                                                Int32(radius), Int32(lineWidth), $0)
        }
    }

    /// Draws the outline of a rectangle with rounded corners, stroked with
    /// `lineWidth`.
    public static func drawRoundRect(_ rect: Rect, radius: Int, lineWidth: Int, color: Color) {
        drawRoundRect(x: rect.left, y: rect.top, width: rect.width, height: rect.height,
                      radius: radius, lineWidth: lineWidth, color: color)
    }

    /// Fills a rectangle with rounded corners.
    public static func fillRoundRect(x: Int, y: Int, width: Int, height: Int, radius: Int, color: Color) {
        color.withLCDColor {
            gfx.pointee.fillRoundRect.unsafelyUnwrapped(Int32(x), Int32(y), Int32(width), Int32(height),
                                                Int32(radius), $0)
        }
    }

    /// Fills a rectangle with rounded corners.
    public static func fillRoundRect(_ rect: Rect, radius: Int, color: Color) {
        fillRoundRect(x: rect.left, y: rect.top, width: rect.width, height: rect.height,
                      radius: radius, color: color)
    }

    /// Draws an ellipse stroked inside the rect. If the angles differ, draws
    /// an arc from `startAngle` to `endAngle` (clockwise degrees, 0 at top).
    public static func drawEllipse(x: Int, y: Int, width: Int, height: Int, lineWidth: Int,
                                   startAngle: Float = 0, endAngle: Float = 0, color: Color) {
        color.withLCDColor {
            gfx.pointee.drawEllipse.unsafelyUnwrapped(Int32(x), Int32(y), Int32(width), Int32(height),
                                              Int32(lineWidth), startAngle, endAngle, $0)
        }
    }

    /// Fills an ellipse inside the rect. If the angles differ, fills the
    /// wedge from `startAngle` to `endAngle` (clockwise degrees, 0 at top).
    public static func fillEllipse(x: Int, y: Int, width: Int, height: Int,
                                   startAngle: Float = 0, endAngle: Float = 0, color: Color) {
        color.withLCDColor {
            gfx.pointee.fillEllipse.unsafelyUnwrapped(Int32(x), Int32(y), Int32(width), Int32(height),
                                              startAngle, endAngle, $0)
        }
    }

    /// Draws an ellipse stroked inside the rect. If the angles differ, draws
    /// an arc from `startAngle` to `endAngle` (clockwise degrees, 0 at top).
    public static func drawEllipse(in rect: Rect, lineWidth: Int,
                                   startAngle: Float = 0, endAngle: Float = 0, color: Color) {
        drawEllipse(x: rect.left, y: rect.top, width: rect.width, height: rect.height,
                    lineWidth: lineWidth, startAngle: startAngle, endAngle: endAngle, color: color)
    }

    /// Fills an ellipse inside the rect. If the angles differ, fills the
    /// wedge from `startAngle` to `endAngle` (clockwise degrees, 0 at top).
    public static func fillEllipse(in rect: Rect,
                                   startAngle: Float = 0, endAngle: Float = 0, color: Color) {
        fillEllipse(x: rect.left, y: rect.top, width: rect.width, height: rect.height,
                    startAngle: startAngle, endAngle: endAngle, color: color)
    }

    /// Fills the polygon described by the points, connecting the last point
    /// back to the first.
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

    /// Sets the pixel at (x, y) in the current drawing context.
    public static func setPixel(x: Int, y: Int, color: Color) {
        color.withLCDColor { gfx.pointee.setPixel.unsafelyUnwrapped(Int32(x), Int32(y), $0) }
    }

    /// Reads an 8×8 pattern from the bitmap starting at (x, y).
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

    /// Draws `text` at (x, y) using the current font. Returns the drawn width.
    @discardableResult
    public static func drawText(_ text: String, x: Int, y: Int) -> Int {
        text.withPlaydateUTF8 { bytes, count in
            Int(gfx.pointee.drawText.unsafelyUnwrapped(bytes, count,
                                                       kUTF8Encoding, Int32(x), Int32(y)))
        }
    }

    /// Draws `text` wrapped and aligned inside the given rectangle.
    public static func drawText(_ text: String, x: Int, y: Int, width: Int, height: Int,
                                wrap: TextWrappingMode = .word, align: TextAlignment = .left) {
        text.withPlaydateUTF8 { bytes, count in
            gfx.pointee.drawTextInRect.unsafelyUnwrapped(bytes, count, kUTF8Encoding,
                                                         Int32(x), Int32(y), Int32(width), Int32(height),
                                                         wrap.cValue, align.cValue)
        }
    }

    /// Draws `text` wrapped and aligned inside the given rectangle.
    public static func drawText(_ text: String, in rect: Rect,
                                wrap: TextWrappingMode = .word, align: TextAlignment = .left) {
        drawText(text, x: rect.left, y: rect.top, width: rect.width, height: rect.height,
                 wrap: wrap, align: align)
    }

    /// Sets the font used by subsequent text drawing.
    public static func setFont(_ font: Font) {
        gfx.pointee.setFont.unsafelyUnwrapped(font.pointer)
    }

    /// Extra space added between letters, in pixels.
    public static var textTracking: Int {
        get { Int(gfx.pointee.getTextTracking.unsafelyUnwrapped()) }
        set { gfx.pointee.setTextTracking.unsafelyUnwrapped(Int32(newValue)) }
    }

    /// Adjusts the line height used when drawing multi-line text.
    public static func setTextLeading(_ lineHeightAdjustment: Int) {
        gfx.pointee.setTextLeading.unsafelyUnwrapped(Int32(lineHeightAdjustment))
    }

    // MARK: - Framebuffer

    /// The current working framebuffer. Rows are `rowSize` bytes.
    /// Call `markUpdatedRows(from:to:)` after writing directly.
    public static var frame: UnsafeMutablePointer<UInt8>? {
        gfx.pointee.getFrame.unsafelyUnwrapped()
    }

    /// The framebuffer currently shown on the display. Rows are `rowSize` bytes.
    public static var displayFrame: UnsafeMutablePointer<UInt8>? {
        gfx.pointee.getDisplayFrame.unsafelyUnwrapped()
    }

    /// A bitmap view of the display framebuffer. Simulator only; `nil` on device.
    public static var debugBitmap: Bitmap? {
        guard let getDebugBitmap = gfx.pointee.getDebugBitmap,
              let pointer = getDebugBitmap() else { return nil }
        return Bitmap(pointer: pointer, isOwned: false)
    }

    /// A bitmap referencing the display framebuffer (not a copy).
    public static var displayBufferBitmap: Bitmap? {
        guard let pointer = gfx.pointee.getDisplayBufferBitmap.unsafelyUnwrapped() else { return nil }
        return Bitmap(pointer: pointer, isOwned: false)
    }

    /// A copy of the working framebuffer as a new bitmap.
    public static func copyFrameBufferBitmap() -> Bitmap? {
        guard let pointer = gfx.pointee.copyFrameBufferBitmap.unsafelyUnwrapped() else { return nil }
        return Bitmap(pointer: pointer, isOwned: true)
    }

    /// Tells the system which rows (inclusive) were changed by direct
    /// framebuffer writes and need redisplay.
    public static func markUpdatedRows(from start: Int, to end: Int) {
        gfx.pointee.markUpdatedRows.unsafelyUnwrapped(Int32(start), Int32(end))
    }

    /// Manually flushes the framebuffer to the display. Only needed when
    /// drawing outside the normal update cycle.
    public static func display() {
        gfx.pointee.display.unsafelyUnwrapped()
    }
}
