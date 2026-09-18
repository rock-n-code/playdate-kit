extension Sound.Signal {
    /// Custom signal callbacks, run on the audio render thread; return quickly.
    public struct Callbacks {
        /// Returns the value at the end of the cycle; `ioFrames` holds its frames left. For
        /// a mid-cycle value, write it to `interpolationValue`, set `ioFrames` to its offset.
        public var step: (_ ioFrames: UnsafeMutablePointer<Int32>?,
                          _ interpolationValue: UnsafeMutablePointer<Float>?) -> Float
        /// `length` is in seconds, or -1 if indefinite.
        public var noteOn: ((_ note: Sound.MIDINote, _ velocity: Float, _ length: Float) -> Void)?
        /// `stopped` is `false` on release, `true` on stop; `offset` is the frame offset
        /// into the cycle.
        public var noteOff: ((_ stopped: Bool, _ offset: Int) -> Void)?

        public init(step: @escaping (_ ioFrames: UnsafeMutablePointer<Int32>?,
                                     _ interpolationValue: UnsafeMutablePointer<Float>?) -> Float,
                    noteOn: ((_ note: Sound.MIDINote, _ velocity: Float, _ length: Float) -> Void)? = nil,
                    noteOff: ((_ stopped: Bool, _ offset: Int) -> Void)? = nil) {
            self.step = step
            self.noteOn = noteOn
            self.noteOff = noteOff
        }
    }
}
