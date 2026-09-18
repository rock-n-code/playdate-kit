internal import CPlaydate

extension Graphics {
    /// Wraps `LCDBitmapDrawMode`: how bitmap and text pixels combine with the destination.
    public enum DrawMode: UInt32, Sendable {
        case copy = 0
        /// White source pixels are transparent.
        case whiteTransparent = 1
        /// Black source pixels are transparent.
        case blackTransparent = 2
        /// Opaque source pixels draw white.
        case fillWhite = 3
        /// Opaque source pixels draw black.
        case fillBlack = 4
        case xor = 5
        case nxor = 6
        case inverted = 7

        init(_ mode: LCDBitmapDrawMode) { self = DrawMode(rawValue: UInt32(mode.rawValue)) ?? .copy }
        var cValue: LCDBitmapDrawMode { LCDBitmapDrawMode(LCDBitmapDrawMode.RawValue(rawValue)) }
    }
}
