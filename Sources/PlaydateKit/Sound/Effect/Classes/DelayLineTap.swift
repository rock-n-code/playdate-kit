internal import CPlaydate

extension Sound {
    /// A tap into a delay line; produces audio and can be added to a channel
    /// as a source. Wraps `DelayLineTap`.
    public final class DelayLineTap: Source {
        private static var api: UnsafePointer<playdate_sound_effect_delayline> { Playdate.delayLineAPI.unsafelyUnwrapped }

        /// The delay line is retained so the tap stays valid.
        private let delayLine: DelayLine
        private var retainedDelayModulator: SignalValue?

        init(pointer: OpaquePointer, delayLine: DelayLine) {
            self.delayLine = delayLine
            super.init(pointer: pointer, isOwned: true)
        }

        deinit {
            DelayLineTap.api.pointee.freeTap.unsafelyUnwrapped(pointer)
        }

        /// The tap's position in the delay line, in frames.
        public func setDelay(frames: Int) {
            DelayLineTap.api.pointee.setTapDelay.unsafelyUnwrapped(pointer, Int32(frames))
        }

        /// Modulates the tap's delay.
        public var delayModulator: SignalValue? {
            get { SignalValue.wrap(DelayLineTap.api.pointee.getTapDelayModulator.unsafelyUnwrapped(pointer)) }
            set {
                retainedDelayModulator = newValue
                DelayLineTap.api.pointee.setTapDelayModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        /// For stereo delay lines: swaps the left and right channels.
        public func setChannelsFlipped(_ flipped: Bool) {
            DelayLineTap.api.pointee.setTapChannelsFlipped.unsafelyUnwrapped(pointer, flipped ? 1 : 0)
        }
    }
}
