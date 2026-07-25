internal import CPlaydate

/// A floating-point rectangle mirroring `PDRect`.
public struct Rect: Sendable {
    public var x: Float
    public var y: Float
    public var width: Float
    public var height: Float

    /// Creates a rect from an origin and size.
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
