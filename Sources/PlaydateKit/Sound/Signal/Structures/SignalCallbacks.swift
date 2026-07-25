extension Sound.Signal {
    /// Custom signal callbacks.
    public struct Callbacks {
        /// Returns the signal's value at the end of the current cycle.
        /// `ioFrames` is the number of frames until the cycle ends and
        /// may be lowered to interpolate toward `interpolationValue`.
        public var step: (_ ioFrames: UnsafeMutablePointer<Int32>?,
                          _ interpolationValue: UnsafeMutablePointer<Float>?) -> Float
        /// Called on note-on events. `length` is -1 for indefinite notes.
        public var noteOn: ((_ note: Sound.MIDINote, _ velocity: Float, _ length: Float) -> Void)?
        /// Called on note-off events. `stopped` is `false` when the note
        /// is released and `true` when it actually stops playing;
        /// `offset` is the frame offset within the current cycle.
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
