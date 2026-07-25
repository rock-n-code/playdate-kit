internal import CPlaydate

extension Sound {
    /// A one-pole low/high-pass filter. Wraps `OnePoleFilter`.
    public final class OnePoleFilter: Effect {
        private static var api: UnsafePointer<playdate_sound_effect_onepolefilter> { Playdate.onePoleFilterAPI.unsafelyUnwrapped }

        private var retainedParameterModulator: SignalValue?

        public init() {
            super.init(pointer: OnePoleFilter.api.pointee.newFilter.unsafelyUnwrapped().unsafelyUnwrapped,
                       isOwned: true)
        }

        deinit {
            if isOwned {
                OnePoleFilter.api.pointee.freeFilter.unsafelyUnwrapped(pointer)
            }
        }

        /// The filter's cutoff: -1 to 1, where values above 0 are low-pass
        /// and values below 0 high-pass.
        public func setParameter(_ parameter: Float) {
            OnePoleFilter.api.pointee.setParameter.unsafelyUnwrapped(pointer, parameter)
        }

        public var parameterModulator: SignalValue? {
            get { SignalValue.wrap(OnePoleFilter.api.pointee.getParameterModulator.unsafelyUnwrapped(pointer)) }
            set {
                retainedParameterModulator = newValue
                OnePoleFilter.api.pointee.setParameterModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }
    }
}
