internal import CPlaydate

extension Graphics {
    /// A drawing color: solid or an 8×8 pattern.
    public enum Color: Sendable {
        /// Solid black.
        case black
        /// Solid white.
        case white
        /// Transparent; leaves the destination unchanged.
        case clear
        /// Inverts the destination pixels.
        case xor
        /// An 8×8 two-color pattern.
        case pattern(Pattern)

        /// Materializes the `LCDColor` for the duration of `body`. Pattern
        /// colors pass a pointer to a temporary, so the value must not be
        /// stored beyond the call.
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
