extension Sound.Effect {
    /// Processes up to `AUDIO_FRAMES_PER_CYCLE` sample frames in signed
    /// Q8.24 format. `bufferActive` is `false` when the input buffer is
    /// silent. Returns `true` if the effect produced output.
    public typealias Processor = (_ left: UnsafeMutableBufferPointer<Int32>,
                                  _ right: UnsafeMutableBufferPointer<Int32>?,
                                  _ bufferActive: Bool) -> Bool
}
