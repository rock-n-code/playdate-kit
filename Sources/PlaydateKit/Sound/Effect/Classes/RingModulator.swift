internal import CPlaydate

extension Sound {
    /// A ring modulator effect. Wraps `RingModulator`.
    public final class RingModulator: Effect {
        private static var api: UnsafePointer<playdate_sound_effect_ringmodulator> { Playdate.ringModulatorAPI.unsafelyUnwrapped }

        private var retainedFrequencyModulator: SignalValue?

        public init() {
            super.init(pointer: RingModulator.api.pointee.newRingmod.unsafelyUnwrapped().unsafelyUnwrapped,
                       isOwned: true)
        }

        deinit {
            if isOwned {
                RingModulator.api.pointee.freeRingmod.unsafelyUnwrapped(pointer)
            }
        }

        /// The modulation frequency, in Hz.
        public func setFrequency(_ frequency: Float) {
            RingModulator.api.pointee.setFrequency.unsafelyUnwrapped(pointer, frequency)
        }

        public var frequencyModulator: SignalValue? {
            get { SignalValue.wrap(RingModulator.api.pointee.getFrequencyModulator.unsafelyUnwrapped(pointer)) }
            set {
                retainedFrequencyModulator = newValue
                RingModulator.api.pointee.setFrequencyModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }
    }
}
