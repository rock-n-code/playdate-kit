internal import CPlaydate

extension Sound {
    /// An overdrive/distortion effect. Wraps `Overdrive`.
    public final class Overdrive: Effect {
        private static var api: UnsafePointer<playdate_sound_effect_overdrive> { Playdate.overdriveAPI.unsafelyUnwrapped }

        private var retainedModulators: [SignalValue] = []

        public init() {
            super.init(pointer: Overdrive.api.pointee.newOverdrive.unsafelyUnwrapped().unsafelyUnwrapped,
                       isOwned: true)
        }

        deinit {
            if isOwned {
                Overdrive.api.pointee.freeOverdrive.unsafelyUnwrapped(pointer)
            }
        }

        /// The input gain applied before clipping.
        public func setGain(_ gain: Float) {
            Overdrive.api.pointee.setGain.unsafelyUnwrapped(pointer, gain)
        }

        /// The level where the amplified input clips.
        public func setLimit(_ limit: Float) {
            Overdrive.api.pointee.setLimit.unsafelyUnwrapped(pointer, limit)
        }

        /// Modulates the clipping limit.
        public var limitModulator: SignalValue? {
            get { SignalValue.wrap(Overdrive.api.pointee.getLimitModulator.unsafelyUnwrapped(pointer)) }
            set {
                retain(newValue)
                Overdrive.api.pointee.setLimitModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        /// A DC offset applied to the input, making the clipping asymmetric.
        public func setOffset(_ offset: Float) {
            Overdrive.api.pointee.setOffset.unsafelyUnwrapped(pointer, offset)
        }

        /// Modulates the DC offset.
        public var offsetModulator: SignalValue? {
            get { SignalValue.wrap(Overdrive.api.pointee.getOffsetModulator.unsafelyUnwrapped(pointer)) }
            set {
                retain(newValue)
                Overdrive.api.pointee.setOffsetModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        private func retain(_ modulator: SignalValue?) {
            if let modulator { retainedModulators.append(modulator) }
        }
    }
}
