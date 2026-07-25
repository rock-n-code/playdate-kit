internal import CPlaydate

extension Graphics {
    /// How text wraps in `drawText(in:)`.
    public enum TextWrappingMode: UInt32, Sendable {
        case clip = 0
        case character = 1
        case word = 2

        var cValue: PDTextWrappingMode { PDTextWrappingMode(PDTextWrappingMode.RawValue(rawValue)) }
    }
}
