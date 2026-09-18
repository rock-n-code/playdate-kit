extension Sound.CallbackSource {
    /// Fills `left` and, if stereo, `right` (else empty) with 16-bit samples.
    /// Returns `false` if the source was silent this cycle.
    public typealias Callback = (_ left: inout MutableSpan<Int16>,
                                 _ right: inout MutableSpan<Int16>) -> Bool
}
