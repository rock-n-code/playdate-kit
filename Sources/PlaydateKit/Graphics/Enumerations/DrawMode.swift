internal import CPlaydate

extension Graphics {
    /// How source pixels combine with the destination when drawing.
    public enum DrawMode: UInt32, Sendable {
        /// Source pixels replace the destination.
        case copy = 0
        /// White source pixels are treated as transparent.
        case whiteTransparent = 1
        /// Black source pixels are treated as transparent.
        case blackTransparent = 2
        /// Opaque source pixels draw white.
        case fillWhite = 3
        /// Opaque source pixels draw black.
        case fillBlack = 4
        /// Source pixels are XORed with the destination.
        case xor = 5
        /// The inverse of `xor`.
        case nxor = 6
        /// Source pixels draw inverted.
        case inverted = 7

        init(_ mode: LCDBitmapDrawMode) { self = DrawMode(rawValue: UInt32(mode.rawValue)) ?? .copy }
        var cValue: LCDBitmapDrawMode { LCDBitmapDrawMode(LCDBitmapDrawMode.RawValue(rawValue)) }
    }
}
