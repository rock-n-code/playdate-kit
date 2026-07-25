internal import CPlaydate

extension Sound {
    /// A two-pole IIR filter. Wraps `TwoPoleFilter`.
    public final class TwoPoleFilter: Effect {
        private static var api: UnsafePointer<playdate_sound_effect_twopolefilter> { Playdate.twoPoleFilterAPI.unsafelyUnwrapped }

        private var retainedFrequencyModulator: SignalValue?
        private var retainedResonanceModulator: SignalValue?

        public init(kind: Kind = .lowPass) {
            super.init(pointer: TwoPoleFilter.api.pointee.newFilter.unsafelyUnwrapped().unsafelyUnwrapped,
                       isOwned: true)
            setKind(kind)
        }

        deinit {
            if isOwned {
                TwoPoleFilter.api.pointee.freeFilter.unsafelyUnwrapped(pointer)
            }
        }

        public func setKind(_ kind: Kind) {
            TwoPoleFilter.api.pointee.setType.unsafelyUnwrapped(pointer, kind.cValue)
        }

        /// The center/corner frequency, in Hz.
        public func setFrequency(_ frequency: Float) {
            TwoPoleFilter.api.pointee.setFrequency.unsafelyUnwrapped(pointer, frequency)
        }

        public var frequencyModulator: SignalValue? {
            get { SignalValue.wrap(TwoPoleFilter.api.pointee.getFrequencyModulator.unsafelyUnwrapped(pointer)) }
            set {
                retainedFrequencyModulator = newValue
                TwoPoleFilter.api.pointee.setFrequencyModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        /// The gain, used by PEQ and shelf filters.
        public func setGain(_ gain: Float) {
            TwoPoleFilter.api.pointee.setGain.unsafelyUnwrapped(pointer, gain)
        }

        public func setResonance(_ resonance: Float) {
            TwoPoleFilter.api.pointee.setResonance.unsafelyUnwrapped(pointer, resonance)
        }

        public var resonanceModulator: SignalValue? {
            get { SignalValue.wrap(TwoPoleFilter.api.pointee.getResonanceModulator.unsafelyUnwrapped(pointer)) }
            set {
                retainedResonanceModulator = newValue
                TwoPoleFilter.api.pointee.setResonanceModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }
    }
}
