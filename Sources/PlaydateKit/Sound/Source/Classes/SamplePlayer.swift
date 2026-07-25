internal import CPlaydate

extension Sound {
    /// Plays an `AudioSample` from memory. Wraps `SamplePlayer`.
    public final class SamplePlayer: Source {
        private static var api: UnsafePointer<playdate_sound_sampleplayer> { Playdate.samplePlayerAPI.unsafelyUnwrapped }

        var loopCallback: ((SamplePlayer) -> Void)?
        private var retainedSample: AudioSample?
        private var retainedRateModulator: SignalValue?

        override init(pointer: OpaquePointer?, isOwned: Bool) {
            super.init(pointer: pointer, isOwned: isOwned)
        }

        public convenience init() {
            self.init(pointer: SamplePlayer.api.pointee.newPlayer.unsafelyUnwrapped().unsafelyUnwrapped,
                      isOwned: true)
        }

        /// Creates a player for the sample at `path`.
        public convenience init(path: String) throws(PlaydateError) {
            self.init()
            sample = try AudioSample(path: path)
        }

        deinit {
            if isOwned {
                SamplePlayer.api.pointee.freePlayer.unsafelyUnwrapped(pointer)
            }
        }

        /// The sample to play.
        public var sample: AudioSample? {
            get { retainedSample }
            set {
                retainedSample = newValue
                SamplePlayer.api.pointee.setSample.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        /// Starts playback at `rate`, looping `repeat` times; 0 loops
        /// endlessly, -1 loops ping-pong.
        @discardableResult
        public func play(repeat repeatCount: Int = 1, rate: Float = 1) -> Bool {
            SamplePlayer.api.pointee.play.unsafelyUnwrapped(pointer, Int32(repeatCount), rate) != 0
        }

        /// Stops playback.
        public func stop() {
            SamplePlayer.api.pointee.stop.unsafelyUnwrapped(pointer)
        }

        /// Pauses or resumes playback.
        public func setPaused(_ paused: Bool) {
            SamplePlayer.api.pointee.setPaused.unsafelyUnwrapped(pointer, paused ? 1 : 0)
        }

        /// The sample's length in seconds.
        public var length: Float {
            SamplePlayer.api.pointee.getLength.unsafelyUnwrapped(pointer)
        }

        /// The playback position in seconds.
        public var offset: Float {
            get { SamplePlayer.api.pointee.getOffset.unsafelyUnwrapped(pointer) }
            set { SamplePlayer.api.pointee.setOffset.unsafelyUnwrapped(pointer, newValue) }
        }

        /// The playback rate; 1 is normal speed, negative plays backward.
        public var rate: Float {
            get { SamplePlayer.api.pointee.getRate.unsafelyUnwrapped(pointer) }
            set { SamplePlayer.api.pointee.setRate.unsafelyUnwrapped(pointer, newValue) }
        }

        /// Restricts playback to the given range of sample frames.
        public func setPlayRange(start: Int, end: Int) {
            SamplePlayer.api.pointee.setPlayRange.unsafelyUnwrapped(pointer, Int32(start), Int32(end))
        }

        /// Sets a function called every time playback loops.
        public func setLoopCallback(_ callback: ((SamplePlayer) -> Void)?) {
            loopCallback = callback
            if callback != nil {
                SamplePlayer.api.pointee.setLoopCallback.unsafelyUnwrapped(pointer, { _, userdata in
                    guard let userdata else { return }
                    let player = Unmanaged<SamplePlayer>.fromOpaque(userdata).takeUnretainedValue()
                    player.loopCallback?(player)
                }, Unmanaged.passUnretained(self).toOpaque())
            } else {
                SamplePlayer.api.pointee.setLoopCallback.unsafelyUnwrapped(pointer, nil, nil)
            }
        }

        /// Modulates the playback rate.
        public var rateModulator: SignalValue? {
            get { SignalValue.wrap(SamplePlayer.api.pointee.getRateModulator.unsafelyUnwrapped(pointer)) }
            set {
                retainedRateModulator = newValue
                SamplePlayer.api.pointee.setRateModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }
    }
}
