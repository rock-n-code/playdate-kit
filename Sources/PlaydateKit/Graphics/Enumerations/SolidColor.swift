internal import CPlaydate

extension Graphics {
    /// A solid color, for APIs that cannot take a pattern.
    public enum SolidColor: UInt32, Sendable {
        case black = 0
        case white = 1
        case clear = 2
        case xor = 3

        init(_ color: LCDSolidColor) { self = SolidColor(rawValue: UInt32(color.rawValue)) ?? .clear }
        var cValue: LCDSolidColor { LCDSolidColor(LCDSolidColor.RawValue(rawValue)) }
    }
}
