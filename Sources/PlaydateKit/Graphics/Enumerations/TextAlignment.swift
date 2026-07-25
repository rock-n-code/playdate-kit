internal import CPlaydate

extension Graphics {
    /// Horizontal alignment for `drawText(in:)`.
    public enum TextAlignment: UInt32, Sendable {
        case left = 0
        case center = 1
        case right = 2

        var cValue: PDTextAlignment { PDTextAlignment(PDTextAlignment.RawValue(rawValue)) }
    }
}
