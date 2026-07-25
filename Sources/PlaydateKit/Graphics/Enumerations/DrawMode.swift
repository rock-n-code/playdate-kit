internal import CPlaydate

extension Graphics {
    /// How source pixels combine with the destination when drawing.
    public enum DrawMode: UInt32, Sendable {
        case copy = 0
        case whiteTransparent = 1
        case blackTransparent = 2
        case fillWhite = 3
        case fillBlack = 4
        case xor = 5
        case nxor = 6
        case inverted = 7

        init(_ mode: LCDBitmapDrawMode) { self = DrawMode(rawValue: UInt32(mode.rawValue)) ?? .copy }
        var cValue: LCDBitmapDrawMode { LCDBitmapDrawMode(LCDBitmapDrawMode.RawValue(rawValue)) }
    }
}
