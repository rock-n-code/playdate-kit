extension Sound.CallbackSource {
    /// Fills the sample buffers and returns `true` if output was
    /// produced. `right` is non-nil only for stereo sources.
    public typealias Callback = (_ left: UnsafeMutableBufferPointer<Int16>,
                                 _ right: UnsafeMutableBufferPointer<Int16>?) -> Bool
}
