internal import CPlaydate

extension Network {
    /// A network error code (`PDNetErr`).
    public enum NetError: Int32, Swift.Error, Sendable {
        case noDevice = -1
        case busy = -2
        case writeError = -3
        case writeBusy = -4
        case writeTimeout = -5
        case readError = -6
        case readBusy = -7
        case readTimeout = -8
        case readOverflow = -9
        case frameError = -10
        case badResponse = -11
        case errorResponse = -12
        case resetTimeout = -13
        case bufferTooSmall = -14
        case unexpectedResponse = -15
        case notConnectedToAP = -16
        case notImplemented = -17
        case connectionClosed = -18
        case unknown = 1

        init(_ error: PDNetErr) {
            self = NetError(rawValue: Int32(error.rawValue)) ?? .unknown
        }
    }
}
