internal import CPlaydate

extension Graphics {
    /// Wrapping for the rect-bounded `drawText` overloads and `Font.textHeight`.
    /// Wraps `PDTextWrappingMode`.
    public enum TextWrappingMode: UInt32, Sendable {
        /// No wrapping; text past the edge is clipped.
        case clip = 0
        case character = 1
        case word = 2

        var cValue: PDTextWrappingMode { PDTextWrappingMode(PDTextWrappingMode.RawValue(rawValue)) }
    }
}
