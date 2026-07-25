internal import CPlaydate

extension Sound.LFO {
    /// The oscillator's waveform.
    public enum Shape: UInt32, Sendable {
        case square = 0
        case triangle = 1
        case sine = 2
        case sampleAndHold = 3
        case sawtoothUp = 4
        case sawtoothDown = 5
        case arpeggiator = 6
        case function = 7

        var cValue: LFOType { LFOType(LFOType.RawValue(rawValue)) }
    }
}
