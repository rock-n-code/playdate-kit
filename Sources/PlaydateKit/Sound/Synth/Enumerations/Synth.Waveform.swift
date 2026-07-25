internal import CPlaydate

extension Sound.Synth {
    /// The synth's waveform.
    public enum Waveform: UInt32, Sendable {
        case square = 0
        case triangle = 1
        case sine = 2
        case noise = 3
        case sawtooth = 4
        /// A Pocket Operator-style phase-distortion waveform.
        case poPhase = 5
        /// A Pocket Operator-style digital waveform.
        case poDigital = 6
        /// A Pocket Operator-style VOSIM (voice simulation) waveform.
        case poVosim = 7

        var cValue: SoundWaveform { SoundWaveform(SoundWaveform.RawValue(rawValue)) }
    }
}
