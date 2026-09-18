internal import CPlaydate

extension Sound.Synth {
    public enum Waveform: UInt32, Sendable {
        /// Parameter 1 sets the pulse width.
        case square = 0
        case triangle = 1
        case sine = 2
        /// White noise.
        case noise = 3
        case sawtooth = 4
        /// Pocket Operator-style phase distortion.
        case poPhase = 5
        /// Pocket Operator-style digital.
        case poDigital = 6
        /// Pocket Operator-style VOSIM (voice simulation).
        case poVosim = 7

        var cValue: SoundWaveform { SoundWaveform(SoundWaveform.RawValue(rawValue)) }
    }
}
