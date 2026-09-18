/// Immediate result of a permission request (microphone, network). Wraps `enum accessReply`.
public enum AccessReply: UInt32, Sendable {
    /// Not answered yet; the completion receives the answer.
    case ask = 0
    /// Already denied; the completion is not called.
    case deny = 1
    /// Already granted; the completion is not called.
    case allow = 2
}
