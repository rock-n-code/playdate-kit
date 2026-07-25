extension Sound {
    /// The microphone used when recording.
    public enum MicSource: UInt32, Sendable {
        /// Use the headset microphone if one is connected, otherwise the
        /// built-in microphone.
        case autodetect = 0
        /// Always use the built-in microphone.
        case internalMic = 1
        /// Always use the headset microphone.
        case headset = 2
    }
}
