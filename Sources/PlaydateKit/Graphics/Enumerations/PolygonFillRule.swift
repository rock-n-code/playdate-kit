internal import CPlaydate

extension Graphics {
    /// The winding rule used by `fillPolygon`.
    public enum PolygonFillRule: UInt32, Sendable {
        case nonZero = 0
        case evenOdd = 1

        var cValue: LCDPolygonFillRule { LCDPolygonFillRule(LCDPolygonFillRule.RawValue(rawValue)) }
    }
}
