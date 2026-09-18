internal import CPlaydate

extension Graphics {
    /// Wraps `LCDColor`: a solid color or an 8×8 pattern.
    public enum Color: Sendable {
        case black
        case white
        /// Leaves the destination unchanged.
        case clear
        /// Inverts the destination.
        case xor
        case pattern(Pattern)

        /// For `.pattern`, the `LCDColor` points to a copy valid only during `body`.
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
}
