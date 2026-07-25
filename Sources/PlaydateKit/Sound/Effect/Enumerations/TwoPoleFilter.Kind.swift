internal import CPlaydate

extension Sound.TwoPoleFilter {
    /// The filter's response type.
    public enum Kind: UInt32, Sendable {
        case lowPass = 0
        case highPass = 1
        case bandPass = 2
        case notch = 3
        /// A parametric EQ filter.
        case peq = 4
        case lowShelf = 5
        case highShelf = 6

        var cValue: TwoPoleFilterType { TwoPoleFilterType(TwoPoleFilterType.RawValue(rawValue)) }
    }
}
