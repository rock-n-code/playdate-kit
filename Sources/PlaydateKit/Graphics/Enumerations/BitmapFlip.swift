internal import CPlaydate

extension Graphics {
    /// Mirroring applied when drawing a bitmap.
    public enum BitmapFlip: UInt32, Sendable {
        case unflipped = 0
        case flippedX = 1
        case flippedY = 2
        case flippedXY = 3

        init(_ flip: LCDBitmapFlip) { self = BitmapFlip(rawValue: UInt32(flip.rawValue)) ?? .unflipped }
        var cValue: LCDBitmapFlip { LCDBitmapFlip(LCDBitmapFlip.RawValue(rawValue)) }
    }
}
