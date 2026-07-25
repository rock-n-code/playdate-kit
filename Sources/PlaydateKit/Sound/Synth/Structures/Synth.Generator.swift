extension Sound.Synth {
    /// Custom generator callbacks. Samples are in signed Q8.24 format.
    public struct Generator {
        /// Renders up to 256 sample frames into `left` (and `right` for
        /// stereo generators). `rate` is the per-frame phase step in
        /// Q0.32 format and `drate` its per-frame change. Returns the
        /// number of frames rendered.
        public var render: (_ left: UnsafeMutableBufferPointer<Int32>,
                            _ right: UnsafeMutableBufferPointer<Int32>?,
                            _ rate: UInt32, _ drate: Int32) -> Int
        /// Called when a note starts. `length` is -1 for indefinite notes.
        public var noteOn: ((_ note: Sound.MIDINote, _ velocity: Float, _ length: Float) -> Void)?
        /// Called when a note is released (`stop == false`) or stopped
        /// (`stop == true`).
        public var release: ((_ stop: Bool) -> Void)?
        /// Sets a generator parameter. Returns `true` if the parameter is
        /// valid.
        public var setParameter: ((_ parameter: Int, _ value: Float) -> Bool)?

        public init(render: @escaping (_ left: UnsafeMutableBufferPointer<Int32>,
                                       _ right: UnsafeMutableBufferPointer<Int32>?,
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
