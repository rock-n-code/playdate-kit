internal import CPlaydate

extension Network {
    /// A network error. Wraps the negative `PDNetErr` codes.
    public enum NetError: Int32, Swift.Error, Sendable {
        /// `NET_NO_DEVICE`.
        case noDevice = -1
        /// `NET_BUSY`.
        case busy = -2
        /// `NET_WRITE_ERROR`.
        case writeError = -3
        /// `NET_WRITE_BUSY`.
        case writeBusy = -4
        /// `NET_WRITE_TIMEOUT`.
        case writeTimeout = -5
        /// `NET_READ_ERROR`.
        case readError = -6
        /// `NET_READ_BUSY`.
        case readBusy = -7
        /// `NET_READ_TIMEOUT`.
        case readTimeout = -8
        /// `NET_READ_OVERFLOW`.
        case readOverflow = -9
        /// `NET_FRAME_ERROR`.
        case frameError = -10
        /// `NET_BAD_RESPONSE`.
        case badResponse = -11
        /// `NET_ERROR_RESPONSE`.
        case errorResponse = -12
        /// `NET_RESET_TIMEOUT`.
        case resetTimeout = -13
        /// `NET_BUFFER_TOO_SMALL`.
        case bufferTooSmall = -14
        /// `NET_UNEXPECTED_RESPONSE`.
        case unexpectedResponse = -15
        /// `NET_NOT_CONNECTED_TO_AP`.
        case notConnectedToAP = -16
        /// `NET_NOT_IMPLEMENTED`.
        case notImplemented = -17
        /// `NET_CONNECTION_CLOSED`.
        case connectionClosed = -18
        /// A code not in `PDNetErr`.
        case unknown = 1

        init(_ error: PDNetErr) {
            self = NetError(rawValue: Int32(error.rawValue)) ?? .unknown
        }
    }
}
