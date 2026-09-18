internal import CPlaydate

extension Sound {
    /// A delay line effect. Wraps `DelayLine`.
    public final class DelayLine: Effect {
        private static var api: UnsafePointer<playdate_sound_effect_delayline> { Playdate.delayLineAPI.unsafelyUnwrapped }

        /// `length` is in frames.
        public init(length: Int, stereo: Bool = false) {
            super.init(pointer: DelayLine.api.pointee.newDelayLine.unsafelyUnwrapped(
                Int32(length), stereo ? 1 : 0).unsafelyUnwrapped, isOwned: true)
        }

        deinit {
            if isOwned {
                DelayLine.api.pointee.freeDelayLine.unsafelyUnwrapped(pointer)
            }
        }

        /// Clears the buffer and reallocates, so not safe while the line is in use.
        public func setLength(frames: Int) {
            DelayLine.api.pointee.setLength.unsafelyUnwrapped(pointer, Int32(frames))
        }

        /// 0...1.
        public func setFeedback(_ feedback: Float) {
            DelayLine.api.pointee.setFeedback.unsafelyUnwrapped(pointer, feedback)
        }

        /// `delay` is in frames behind the write head, at most the line's length.
        /// The tap keeps the line alive.
        public func addTap(delay: Int) -> DelayLineTap? {
            guard let tap = DelayLine.api.pointee.addTap.unsafelyUnwrapped(pointer, Int32(delay)) else {
                return nil
            }
            return DelayLineTap(pointer: tap, delayLine: self)
        }
    }
}
