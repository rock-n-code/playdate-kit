extension Sound.Effect {
    /// Processes up to 512 (`AUDIO_FRAMES_PER_CYCLE`) signed Q8.24 frames in place.
    /// `right` is empty on mono channels; `bufferActive` is `false` if nothing was
    /// written. Returns `true` if it changed the samples.
    public typealias Processor = (_ left: inout MutableSpan<Int32>,
                                  _ right: inout MutableSpan<Int32>,
                                  _ bufferActive: Bool) -> Bool
}
