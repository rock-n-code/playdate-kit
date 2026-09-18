extension Sound.Synth {
    /// Custom generator callbacks, run on the audio render thread; return quickly.
    /// Samples are signed Q8.24.
    public struct Generator {
        /// Renders `left.count` frames into `left` and `right` (empty if mono). `rate` is the
        /// per-frame Q0.32 phase step, `drate` its per-frame change. Returns frames rendered.
        public var render: (_ left: inout MutableSpan<Int32>,
                            _ right: inout MutableSpan<Int32>,
                            _ rate: UInt32, _ drate: Int32) -> Int
        /// `length` is in seconds, or -1 if indefinite.
        public var noteOn: ((_ note: Sound.MIDINote, _ velocity: Float, _ length: Float) -> Void)?
        /// `stop` is `false` on release, `true` on stop.
        public var release: ((_ stop: Bool) -> Void)?
        /// Called by `Synth.setParameter(_:value:)` or a modulator. Returns `true` if valid.
        public var setParameter: ((_ parameter: Int, _ value: Float) -> Bool)?

        public init(render: @escaping (_ left: inout MutableSpan<Int32>,
                                       _ right: inout MutableSpan<Int32>,
                                       _ rate: UInt32, _ drate: Int32) -> Int,
                    noteOn: ((_ note: Sound.MIDINote, _ velocity: Float, _ length: Float) -> Void)? = nil,
                    release: ((_ stop: Bool) -> Void)? = nil,
                    setParameter: ((_ parameter: Int, _ value: Float) -> Bool)? = nil) {
            self.render = render
            self.noteOn = noteOn
            self.release = release
            self.setParameter = setParameter
        }
    }
}
