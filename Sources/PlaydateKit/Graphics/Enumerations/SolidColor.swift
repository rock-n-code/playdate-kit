internal import CPlaydate

extension Graphics {
    /// A color for APIs that cannot take a pattern. Wraps `LCDSolidColor`.
    public enum SolidColor: UInt32, Sendable {
        case black = 0
        case white = 1
        /// Transparent.
        case clear = 2
        /// Inverts the destination.
        case xor = 3

        init(_ color: LCDSolidColor) { self = SolidColor(rawValue: UInt32(color.rawValue)) ?? .clear }
        var cValue: LCDSolidColor { LCDSolidColor(LCDSolidColor.RawValue(rawValue)) }
    }
}
