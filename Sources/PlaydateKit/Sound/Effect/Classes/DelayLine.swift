internal import CPlaydate

extension Sound {
    /// A delay line effect. Wraps `DelayLine`.
    public final class DelayLine: Effect {
        private static var api: UnsafePointer<playdate_sound_effect_delayline> { Playdate.delayLineAPI.unsafelyUnwrapped }

        /// Creates a delay line holding `length` frames.
        public init(length: Int, stereo: Bool = false) {
            super.init(pointer: DelayLine.api.pointee.newDelayLine.unsafelyUnwrapped(
                Int32(length), stereo ? 1 : 0).unsafelyUnwrapped, isOwned: true)
        }

        deinit {
            if isOwned {
                DelayLine.api.pointee.freeDelayLine.unsafelyUnwrapped(pointer)
            }
        }

        /// Changes the delay length. Cannot be larger than the line's
        /// original length.
        public func setLength(frames: Int) {
            DelayLine.api.pointee.setLength.unsafelyUnwrapped(pointer, Int32(frames))
        }

        /// The feedback level, 0...1.
        public func setFeedback(_ feedback: Float) {
            DelayLine.api.pointee.setFeedback.unsafelyUnwrapped(pointer, feedback)
        }

        /// Adds a tap `delay` frames behind the write head. The tap can be
        /// added to a channel as a sound source.
        public func addTap(delay: Int) -> DelayLineTap? {
            guard let tap = DelayLine.api.pointee.addTap.unsafelyUnwrapped(pointer, Int32(delay)) else {
                return nil
            }
            return DelayLineTap(pointer: tap, delayLine: self)
        }
    }
}
