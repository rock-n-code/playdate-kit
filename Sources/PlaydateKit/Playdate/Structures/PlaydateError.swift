/// An error reported by the Playdate OS.
public struct PlaydateError: Swift.Error, Sendable {
    /// The OS message, or a description of the failure.
    public let message: String

    init(message: String) {
        self.message = message
    }

    /// Copies an OS C string; null yields "unknown error".
    init(cString: UnsafePointer<CChar>?) {
        self.init(message: String(playdateCString: cString) ?? "unknown error")
    }
}
