internal import CPlaydate

extension Graphics {
    /// The end cap style used when drawing lines.
    public enum LineCapStyle: UInt32, Sendable {
        case butt = 0
        case square = 1
        case round = 2

        var cValue: LCDLineCapStyle { LCDLineCapStyle(LCDLineCapStyle.RawValue(rawValue)) }
    }
}
