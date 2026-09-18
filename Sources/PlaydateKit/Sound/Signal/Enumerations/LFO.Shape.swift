internal import CPlaydate

extension Sound.LFO {
    public enum Shape: UInt32, Sendable {
        case square = 0
        case triangle = 1
        case sine = 2
        /// Random values, held for each cycle.
        case sampleAndHold = 3
        case sawtoothUp = 4
        case sawtoothDown = 5
        /// Steps through the values set by `setArpeggiation(_:)`.
        case arpeggiator = 6
        /// Values come from the function set by `setFunction(interpolate:_:)`.
        case function = 7

        var cValue: LFOType { LFOType(LFOType.RawValue(rawValue)) }
    }
}
