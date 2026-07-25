/// An error reported by the Playdate OS.
public struct PlaydateError: Swift.Error, Sendable {
    /// The message reported by the OS, or a description of the failure.
    public let message: String

    /// Creates an error with the given message.
    init(message: String) {
        self.message = message
    }

    /// Creates an error by copying an OS-provided C string; a nil pointer
    /// produces "unknown error".
    init(cString: UnsafePointer<CChar>?) {
        self.init(message: String(playdateCString: cString) ?? "unknown error")
    }
}
