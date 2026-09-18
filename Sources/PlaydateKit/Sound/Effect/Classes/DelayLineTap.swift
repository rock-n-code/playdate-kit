internal import CPlaydate

extension Sound {
    /// A read point on a delay line, playable as a channel source. Wraps `DelayLineTap`.
    public final class DelayLineTap: Source {
        private static var api: UnsafePointer<playdate_sound_effect_delayline> { Playdate.delayLineAPI.unsafelyUnwrapped }

        /// Kept alive: the tap reads from its buffer.
        private let delayLine: DelayLine
        private var retainedDelayModulator: SignalValue?

        init(pointer: OpaquePointer, delayLine: DelayLine) {
            self.delayLine = delayLine
            super.init(pointer: pointer, isOwned: true)
        }

        deinit {
            DelayLineTap.api.pointee.freeTap.unsafelyUnwrapped(pointer)
        }

        /// In frames, up to the delay line's length.
        public func setDelay(frames: Int) {
            DelayLineTap.api.pointee.setTapDelay.unsafelyUnwrapped(pointer, Int32(frames))
        }

        /// A continuous signal speeds up or slows down playback.
        public var delayModulator: SignalValue? {
            get { SignalValue.wrap(DelayLineTap.api.pointee.getTapDelayModulator.unsafelyUnwrapped(pointer)) }
            set {
                retainedDelayModulator = newValue
                DelayLineTap.api.pointee.setTapDelayModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        /// Stereo delay lines only.
        public func setChannelsFlipped(_ flipped: Bool) {
            DelayLineTap.api.pointee.setTapChannelsFlipped.unsafelyUnwrapped(pointer, flipped ? 1 : 0)
        }
    }
}
