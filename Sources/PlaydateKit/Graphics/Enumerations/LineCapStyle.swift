internal import CPlaydate

extension Graphics {
    /// Line end caps. Wraps `LCDLineCapStyle`.
    public enum LineCapStyle: UInt32, Sendable {
        /// Flat, ending at the endpoint.
        case butt = 0
        /// Square, extending past the endpoint.
        case square = 1
        case round = 2

        var cValue: LCDLineCapStyle { LCDLineCapStyle(LCDLineCapStyle.RawValue(rawValue)) }
    }
}
