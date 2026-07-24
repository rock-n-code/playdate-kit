//
//  Network.swift
//  Wraps `playdate->network` (pd_api_network.h): HTTP and TCP connections.
//
//  The binding stores a back-reference to each connection wrapper in the
//  underlying object's userdata slot so callbacks can recover the wrapper;
//  the C userdata slot is therefore reserved by the binding.
//

internal import CPlaydate

private var networkAPI: playdate_network { Playdate.api.network.pointee }
private var httpAPI: playdate_http { networkAPI.http.pointee }
private var tcpAPI: playdate_tcp { networkAPI.tcp.pointee }

/// The network API: wifi status, HTTP, and TCP.
public enum Network {}

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
            self = NetError(rawValue: error.rawValue) ?? .unknown
        }
    }

    /// Throws unless `error` is `NET_OK`.
    static func check(_ error: PDNetErr) throws(NetError) {
        if error != NET_OK {
            throw NetError(error)
        }
    }

    /// Converts an error code to `nil` (OK) or a `NetError`.
    static func optionalError(_ error: PDNetErr) -> NetError? {
        error == NET_OK ? nil : NetError(error)
    }

    /// The device's wifi status.
    public enum WifiStatus: UInt32, Sendable {
        case notConnected = 0
        case connected = 1
        /// A connection was attempted but no configured access point was
        /// available.
        case notAvailable = 2
    }

    public static var status: WifiStatus {
        WifiStatus(rawValue: networkAPI.getStatus.unsafelyUnwrapped().rawValue) ?? .notConnected
    }

    /// Turns the wifi radio on or off. The completion receives `nil` on
    /// success.
    public static func setEnabled(_ enabled: Bool, completion: ((NetError?) -> Void)? = nil) {
        setEnabledCompletion = completion
        if completion != nil {
            networkAPI.setEnabled.unsafelyUnwrapped(enabled, { error in
                let completion = Network.setEnabledCompletion
                Network.setEnabledCompletion = nil
                completion?(Network.optionalError(error))
            })
        } else {
            networkAPI.setEnabled.unsafelyUnwrapped(enabled, nil)
        }
    }

    nonisolated(unsafe) private static var setEnabledCompletion: ((NetError?) -> Void)?

    /// Requests permission to connect to `server`. Shared by HTTP and TCP.
    fileprivate static func requestAccess(
        rawRequest: (UnsafePointer<CChar>?, Int32, Bool, UnsafePointer<CChar>?,
                     (@convention(c) (Bool, UnsafeMutableRawPointer?) -> Void)?,
                     UnsafeMutableRawPointer?) -> accessReply,
        server: String, port: Int, useSSL: Bool, purpose: String?,
        completion: @escaping (Bool) -> Void) -> AccessReply {
        final class Box {
            let body: (Bool) -> Void
            init(_ body: @escaping (Bool) -> Void) { self.body = body }
        }
        let box = Unmanaged.passRetained(Box(completion))
        let trampoline: @convention(c) (Bool, UnsafeMutableRawPointer?) -> Void = { allowed, userdata in
            guard let userdata else { return }
            Unmanaged<Box>.fromOpaque(userdata).takeRetainedValue().body(allowed)
        }
        let reply = server.withPlaydateCString { cServer in
            if let purpose {
                return purpose.withPlaydateCString { cPurpose in
                    rawRequest(cServer, Int32(port), useSSL, cPurpose, trampoline, box.toOpaque())
                }
            } else {
                return rawRequest(cServer, Int32(port), useSSL, nil, trampoline, box.toOpaque())
            }
        }
        if reply != kAccessAsk {
            // The callback will not be invoked; balance the retain.
            box.release()
        }
        return AccessReply(rawValue: reply.rawValue) ?? .ask
    }

    // MARK: - HTTP

    /// An HTTP connection to a server. Wraps `HTTPConnection`.
    public final class HTTPConnection {
        let pointer: OpaquePointer

        var headerReceivedCallback: ((HTTPConnection, _ key: String, _ value: String) -> Void)?
        var headersReadCallback: ((HTTPConnection) -> Void)?
        var responseCallback: ((HTTPConnection) -> Void)?
        var requestCompleteCallback: ((HTTPConnection) -> Void)?
        var connectionClosedCallback: ((HTTPConnection) -> Void)?

        /// Requests permission to connect to `server`. If the reply is
        /// `.ask`, the completion is called later with the user's answer.
        @discardableResult
        public static func requestAccess(server: String, port: Int = 443, useSSL: Bool = true,
                                         purpose: String? = nil,
                                         completion: @escaping (Bool) -> Void) -> AccessReply {
            Network.requestAccess(
                rawRequest: { httpAPI.requestAccess.unsafelyUnwrapped($0, $1, $2, $3, $4, $5) },
                server: server, port: port, useSSL: useSSL, purpose: purpose,
                completion: completion)
        }

        /// Opens a connection to `server`. Fails if access has not been
        /// granted.
        public init?(server: String, port: Int = 443, useSSL: Bool = true) {
            let pointer = server.withPlaydateCString {
                httpAPI.newConnection.unsafelyUnwrapped($0, Int32(port), useSSL)
            }
            guard let pointer else { return nil }
            self.pointer = pointer
            httpAPI.setUserdata.unsafelyUnwrapped(pointer, Unmanaged.passUnretained(self).toOpaque())
        }

        deinit {
            httpAPI.setUserdata.unsafelyUnwrapped(pointer, nil)
            httpAPI.release.unsafelyUnwrapped(pointer)
        }

        private static func wrapper(for pointer: OpaquePointer?) -> HTTPConnection? {
            guard let pointer,
                  let userdata = httpAPI.getUserdata.unsafelyUnwrapped(pointer) else { return nil }
            return Unmanaged<HTTPConnection>.fromOpaque(userdata).takeUnretainedValue()
        }

        // MARK: Configuration

        /// The time to wait for the connection to open, in milliseconds.
        public func setConnectTimeout(milliseconds: Int) {
            httpAPI.setConnectTimeout.unsafelyUnwrapped(pointer, Int32(milliseconds))
        }

        /// Whether to keep the connection open after a request completes.
        public func setKeepAlive(_ keepAlive: Bool) {
            httpAPI.setKeepAlive.unsafelyUnwrapped(pointer, keepAlive)
        }

        /// Adds a `Range: bytes=start-end` header to future requests.
        public func setByteRange(start: Int, end: Int) {
            httpAPI.setByteRange.unsafelyUnwrapped(pointer, Int32(start), Int32(end))
        }

        /// The time to wait for incoming data, in milliseconds.
        public func setReadTimeout(milliseconds: Int) {
            httpAPI.setReadTimeout.unsafelyUnwrapped(pointer, Int32(milliseconds))
        }

        /// The size of the connection's read buffer, in bytes.
        public func setReadBufferSize(bytes: Int) {
            httpAPI.setReadBufferSize.unsafelyUnwrapped(pointer, Int32(bytes))
        }

        // MARK: Requests

        /// Sends a GET request for `path`. `headers` are raw header lines
        /// (e.g. "Accept: text/html\r\n").
        public func get(path: String, headers: String = "") throws(NetError) {
            let error = path.withPlaydateCString { cPath in
                headers.withPlaydateCString { cHeaders in
                    httpAPI.get.unsafelyUnwrapped(pointer, cPath, cHeaders, headers.utf8.count)
                }
            }
            try Network.check(error)
        }

        /// Sends a POST request for `path` with the given body.
        public func post(path: String, headers: String = "", body: [UInt8]) throws(NetError) {
            let error = path.withPlaydateCString { cPath in
                headers.withPlaydateCString { cHeaders in
                    body.withUnsafeBytes { bodyBuffer in
                        httpAPI.post.unsafelyUnwrapped(
                            pointer, cPath, cHeaders, headers.utf8.count,
                            bodyBuffer.baseAddress?.assumingMemoryBound(to: CChar.self),
                            bodyBuffer.count)
                    }
                }
            }
            try Network.check(error)
        }

        /// Sends a request with an arbitrary HTTP method.
        public func query(method: String, path: String, headers: String = "",
                          body: [UInt8] = []) throws(NetError) {
            let error = method.withPlaydateCString { cMethod in
                path.withPlaydateCString { cPath in
                    headers.withPlaydateCString { cHeaders in
                        body.withUnsafeBytes { bodyBuffer in
                            httpAPI.query.unsafelyUnwrapped(
                                pointer, cMethod, cPath, cHeaders, headers.utf8.count,
                                bodyBuffer.baseAddress?.assumingMemoryBound(to: CChar.self),
                                bodyBuffer.count)
                        }
                    }
                }
            }
            try Network.check(error)
        }

        // MARK: Response

        /// The last error on the connection, if any.
        public var error: NetError? {
            Network.optionalError(httpAPI.getError.unsafelyUnwrapped(pointer))
        }

        /// The number of bytes read of the current response, and the total
        /// expected (0 if the response has no Content-Length).
        public var progress: (read: Int, total: Int) {
            var read: Int32 = 0, total: Int32 = 0
            httpAPI.getProgress.unsafelyUnwrapped(pointer, &read, &total)
            return (Int(read), Int(total))
        }

        /// The HTTP status code of the response.
        public var responseStatus: Int {
            Int(httpAPI.getResponseStatus.unsafelyUnwrapped(pointer))
        }

        /// The number of response bytes available to read.
        public var bytesAvailable: Int {
            Int(httpAPI.getBytesAvailable.unsafelyUnwrapped(pointer))
        }

        /// Reads up to `buffer.count` response bytes. Returns the number of
        /// bytes read.
        public func read(into buffer: UnsafeMutableRawBufferPointer) throws(NetError) -> Int {
            let result = httpAPI.read.unsafelyUnwrapped(pointer, buffer.baseAddress,
                                                        UInt32(buffer.count))
            if result < 0 {
                throw NetError(rawValue: result) ?? .unknown
            }
            return Int(result)
        }

        /// Reads up to `length` available response bytes.
        public func read(length: Int) throws(NetError) -> [UInt8] {
            var bytes = [UInt8](repeating: 0, count: length)
            let result = bytes.withUnsafeMutableBytes { buffer in
                httpAPI.read.unsafelyUnwrapped(pointer, buffer.baseAddress, UInt32(buffer.count))
            }
            if result < 0 {
                throw NetError(rawValue: result) ?? .unknown
            }
            bytes.removeLast(length - Int(result))
            return bytes
        }

        /// Closes the connection.
        public func close() {
            httpAPI.close.unsafelyUnwrapped(pointer)
        }

        // MARK: Callbacks

        /// Called for each header line as it arrives.
        public func setHeaderReceivedCallback(_ callback: ((HTTPConnection, _ key: String, _ value: String) -> Void)?) {
            headerReceivedCallback = callback
            if callback != nil {
                httpAPI.setHeaderReceivedCallback.unsafelyUnwrapped(pointer, { connection, key, value in
                    guard let wrapper = HTTPConnection.wrapper(for: connection),
                          let key = String(playdateCString: key),
                          let value = String(playdateCString: value) else { return }
                    wrapper.headerReceivedCallback?(wrapper, key, value)
                })
            } else {
                httpAPI.setHeaderReceivedCallback.unsafelyUnwrapped(pointer, nil)
            }
        }

        /// Called when all headers have been read.
        public func setHeadersReadCallback(_ callback: ((HTTPConnection) -> Void)?) {
            headersReadCallback = callback
            if callback != nil {
                httpAPI.setHeadersReadCallback.unsafelyUnwrapped(pointer, { connection in
                    guard let wrapper = HTTPConnection.wrapper(for: connection) else { return }
                    wrapper.headersReadCallback?(wrapper)
                })
            } else {
                httpAPI.setHeadersReadCallback.unsafelyUnwrapped(pointer, nil)
            }
        }

        /// Called when response data is available to read.
        public func setResponseCallback(_ callback: ((HTTPConnection) -> Void)?) {
            responseCallback = callback
            if callback != nil {
                httpAPI.setResponseCallback.unsafelyUnwrapped(pointer, { connection in
                    guard let wrapper = HTTPConnection.wrapper(for: connection) else { return }
                    wrapper.responseCallback?(wrapper)
                })
            } else {
                httpAPI.setResponseCallback.unsafelyUnwrapped(pointer, nil)
            }
        }

        /// Called when the request finishes.
        public func setRequestCompleteCallback(_ callback: ((HTTPConnection) -> Void)?) {
            requestCompleteCallback = callback
            if callback != nil {
                httpAPI.setRequestCompleteCallback.unsafelyUnwrapped(pointer, { connection in
                    guard let wrapper = HTTPConnection.wrapper(for: connection) else { return }
                    wrapper.requestCompleteCallback?(wrapper)
                })
            } else {
                httpAPI.setRequestCompleteCallback.unsafelyUnwrapped(pointer, nil)
            }
        }

        /// Called when the connection closes.
        public func setConnectionClosedCallback(_ callback: ((HTTPConnection) -> Void)?) {
            connectionClosedCallback = callback
            if callback != nil {
                httpAPI.setConnectionClosedCallback.unsafelyUnwrapped(pointer, { connection in
                    guard let wrapper = HTTPConnection.wrapper(for: connection) else { return }
                    wrapper.connectionClosedCallback?(wrapper)
                })
            } else {
                httpAPI.setConnectionClosedCallback.unsafelyUnwrapped(pointer, nil)
            }
        }
    }

    // MARK: - TCP

    /// A TCP connection to a server. Wraps `TCPConnection`.
    public final class TCPConnection {
        let pointer: OpaquePointer

        var openCompletion: ((TCPConnection, NetError?) -> Void)?
        var connectionClosedCallback: ((TCPConnection, NetError?) -> Void)?

        /// Requests permission to connect to `server`. If the reply is
        /// `.ask`, the completion is called later with the user's answer.
        @discardableResult
        public static func requestAccess(server: String, port: Int, useSSL: Bool = true,
                                         purpose: String? = nil,
                                         completion: @escaping (Bool) -> Void) -> AccessReply {
            Network.requestAccess(
                rawRequest: { tcpAPI.requestAccess.unsafelyUnwrapped($0, $1, $2, $3, $4, $5) },
                server: server, port: port, useSSL: useSSL, purpose: purpose,
                completion: completion)
        }

        /// Creates a connection to `server`. Fails if access has not been
        /// granted. Call `open(_:)` to connect.
        public init?(server: String, port: Int, useSSL: Bool = true) {
            let pointer = server.withPlaydateCString {
                tcpAPI.newConnection.unsafelyUnwrapped($0, Int32(port), useSSL)
            }
            guard let pointer else { return nil }
            self.pointer = pointer
            tcpAPI.setUserdata.unsafelyUnwrapped(pointer, Unmanaged.passUnretained(self).toOpaque())
        }

        deinit {
            tcpAPI.setUserdata.unsafelyUnwrapped(pointer, nil)
            tcpAPI.release.unsafelyUnwrapped(pointer)
        }

        private static func wrapper(for pointer: OpaquePointer?) -> TCPConnection? {
            guard let pointer,
                  let userdata = tcpAPI.getUserdata.unsafelyUnwrapped(pointer) else { return nil }
            return Unmanaged<TCPConnection>.fromOpaque(userdata).takeUnretainedValue()
        }

        /// The last error on the connection, if any.
        public var error: NetError? {
            Network.optionalError(tcpAPI.getError.unsafelyUnwrapped(pointer))
        }

        /// The time to wait for the connection to open, in milliseconds.
        public func setConnectTimeout(milliseconds: Int) {
            tcpAPI.setConnectTimeout.unsafelyUnwrapped(pointer, Int32(milliseconds))
        }

        /// Opens the connection. The completion receives `nil` on success.
        public func open(_ completion: @escaping (TCPConnection, NetError?) -> Void) throws(NetError) {
            openCompletion = completion
            let error = tcpAPI.open.unsafelyUnwrapped(pointer, { connection, error, _ in
                guard let wrapper = TCPConnection.wrapper(for: connection) else { return }
                let completion = wrapper.openCompletion
                wrapper.openCompletion = nil
                completion?(wrapper, Network.optionalError(error))
            }, nil)
            try Network.check(error)
        }

        /// Closes the connection.
        public func close() throws(NetError) {
            try Network.check(tcpAPI.close.unsafelyUnwrapped(pointer))
        }

        /// Called when the connection closes, with the reason if it closed
        /// due to an error.
        public func setConnectionClosedCallback(_ callback: ((TCPConnection, NetError?) -> Void)?) {
            connectionClosedCallback = callback
            if callback != nil {
                tcpAPI.setConnectionClosedCallback.unsafelyUnwrapped(pointer, { connection, error in
                    guard let wrapper = TCPConnection.wrapper(for: connection) else { return }
                    wrapper.connectionClosedCallback?(wrapper, Network.optionalError(error))
                })
            } else {
                tcpAPI.setConnectionClosedCallback.unsafelyUnwrapped(pointer, nil)
            }
        }

        /// The time to wait for incoming data, in milliseconds.
        public func setReadTimeout(milliseconds: Int) {
            tcpAPI.setReadTimeout.unsafelyUnwrapped(pointer, Int32(milliseconds))
        }

        /// The size of the connection's read buffer, in bytes.
        public func setReadBufferSize(bytes: Int) {
            tcpAPI.setReadBufferSize.unsafelyUnwrapped(pointer, Int32(bytes))
        }

        /// The number of bytes available to read.
        public var bytesAvailable: Int {
            Int(tcpAPI.getBytesAvailable.unsafelyUnwrapped(pointer))
        }

        /// The number of written bytes not yet sent on the wire.
        public var sentBytesPending: Int {
            Int(tcpAPI.getSentBytesPending.unsafelyUnwrapped(pointer))
        }

        /// Reads up to `buffer.count` bytes, waiting up to the read timeout.
        /// Returns the number of bytes read.
        public func read(into buffer: UnsafeMutableRawBufferPointer) throws(NetError) -> Int {
            let result = tcpAPI.read.unsafelyUnwrapped(pointer, buffer.baseAddress, buffer.count)
            if result < 0 {
                throw NetError(rawValue: result) ?? .unknown
            }
            return Int(result)
        }

        /// Reads up to `length` bytes, waiting up to the read timeout.
        public func read(length: Int) throws(NetError) -> [UInt8] {
            var bytes = [UInt8](repeating: 0, count: length)
            let result = bytes.withUnsafeMutableBytes { buffer in
                tcpAPI.read.unsafelyUnwrapped(pointer, buffer.baseAddress, buffer.count)
            }
            if result < 0 {
                throw NetError(rawValue: result) ?? .unknown
            }
            bytes.removeLast(length - Int(result))
            return bytes
        }

        /// Writes the buffer to the connection. Returns the number of bytes
        /// accepted.
        @discardableResult
        public func write(_ buffer: UnsafeRawBufferPointer) throws(NetError) -> Int {
            let result = tcpAPI.write.unsafelyUnwrapped(pointer, buffer.baseAddress, buffer.count)
            if result < 0 {
                throw NetError(rawValue: result) ?? .unknown
            }
            return Int(result)
        }

        /// Writes the bytes to the connection. Returns the number of bytes
        /// accepted.
        @discardableResult
        public func write(_ bytes: [UInt8]) throws(NetError) -> Int {
            let result = bytes.withUnsafeBytes { buffer in
                tcpAPI.write.unsafelyUnwrapped(pointer, buffer.baseAddress, buffer.count)
            }
            if result < 0 {
                throw NetError(rawValue: result) ?? .unknown
            }
            return Int(result)
        }
    }
}
