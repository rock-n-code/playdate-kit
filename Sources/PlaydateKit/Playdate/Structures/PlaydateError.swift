/// An error reported by the Playdate OS.
public struct PlaydateError: Swift.Error, Sendable {
    public let message: String

    init(message: String) {
        self.message = message
    }

    init(cString: UnsafePointer<CChar>?) {
        self.init(message: String(playdateCString: cString) ?? "unknown error")
    }
}
