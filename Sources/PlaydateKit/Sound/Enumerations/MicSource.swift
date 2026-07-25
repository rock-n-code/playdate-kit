extension Sound {
    /// The microphone used when recording.
    public enum MicSource: UInt32, Sendable {
        case autodetect = 0
        case internalMic = 1
        case headset = 2
    }
}
