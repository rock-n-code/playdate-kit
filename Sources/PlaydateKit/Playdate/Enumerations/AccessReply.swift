/// The user's answer to a permission request (microphone, network).
public enum AccessReply: UInt32, Sendable {
    case ask = 0
    case deny = 1
    case allow = 2
}
