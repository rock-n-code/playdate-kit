internal import CPlaydate

extension Graphics {
    /// Winding rule for `fillPolygon(points:color:fillRule:)`. Wraps `LCDPolygonFillRule`.
    public enum PolygonFillRule: UInt32, Sendable {
        /// Fills points with a nonzero winding number.
        case nonZero = 0
        /// Fills points crossed by an odd number of edges.
        case evenOdd = 1

        var cValue: LCDPolygonFillRule { LCDPolygonFillRule(LCDPolygonFillRule.RawValue(rawValue)) }
    }
}
