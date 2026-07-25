/// The user's answer to a permission request (microphone, network).
public enum AccessReply: UInt32, Sendable {
    /// The user has not answered yet; the request's completion delivers
    /// the answer later.
    case ask = 0
    /// The user has already denied access; the completion is not called.
    case deny = 1
    /// The user has already granted access; the completion is not called.
    case allow = 2
}
