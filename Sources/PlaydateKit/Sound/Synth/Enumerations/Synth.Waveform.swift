internal import CPlaydate

extension Sound.Synth {
    /// The synth's waveform.
    public enum Waveform: UInt32, Sendable {
        case square = 0
        case triangle = 1
        case sine = 2
        case noise = 3
        case sawtooth = 4
        case poPhase = 5
        case poDigital = 6
        case poVosim = 7

        var cValue: SoundWaveform { SoundWaveform(SoundWaveform.RawValue(rawValue)) }
    }
}
