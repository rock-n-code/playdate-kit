internal import CPlaydate

/// A floating-point rectangle, in pixels. Wraps `PDRect`.
public struct Rect: Sendable {
    /// Left edge.
    public var x: Float
    /// Top edge.
    public var y: Float
    public var width: Float
    public var height: Float

    public init(x: Float, y: Float, width: Float, height: Float) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    init(_ rect: PDRect) {
        self.init(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }

    var cValue: PDRect { PDRect(x: x, y: y, width: width, height: height) }
}
