internal import CPlaydate

/// The cached `playdate->network->http` C API table.
private var httpAPI: UnsafePointer<playdate_http> { Playdate.httpAPI.unsafelyUnwrapped }

extension Network {
    /// An HTTP connection to a server. Wraps `HTTPConnection`.
    ///
    /// The binding stores a back-reference to each wrapper in the
    /// underlying object's userdata slot so callbacks can recover the
    /// wrapper; the C userdata slot is therefore reserved by the binding.
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
                rawRequest: { httpAPI.pointee.requestAccess.unsafelyUnwrapped($0, $1, $2, $3, $4, $5) },
                server: server, port: port, useSSL: useSSL, purpose: purpose,
                completion: completion)
        }

        /// Opens a connection to `server`. Fails if access has not been
        /// granted.
        public init?(server: String, port: Int = 443, useSSL: Bool = true) {
            let pointer = server.withPlaydateCString {
                httpAPI.pointee.newConnection.unsafelyUnwrapped($0, Int32(port), useSSL)
            }
            guard let pointer else { return nil }
            self.pointer = pointer
            httpAPI.pointee.setUserdata.unsafelyUnwrapped(pointer, Unmanaged.passUnretained(self).toOpaque())
        }

        deinit {
            httpAPI.pointee.setUserdata.unsafelyUnwrapped(pointer, nil)
            httpAPI.pointee.release.unsafelyUnwrapped(pointer)
        }

        private static func wrapper(for pointer: OpaquePointer?) -> HTTPConnection? {
            guard let pointer,
                  let userdata = httpAPI.pointee.getUserdata.unsafelyUnwrapped(pointer) else { return nil }
            return Unmanaged<HTTPConnection>.fromOpaque(userdata).takeUnretainedValue()
        }

        // MARK: Configuration

        /// The time to wait for the connection to open, in milliseconds.
        public func setConnectTimeout(milliseconds: Int) {
            httpAPI.pointee.setConnectTimeout.unsafelyUnwrapped(pointer, Int32(milliseconds))
        }

        /// Whether to keep the connection open after a request completes.
        public func setKeepAlive(_ keepAlive: Bool) {
            httpAPI.pointee.setKeepAlive.unsafelyUnwrapped(pointer, keepAlive)
        }

        /// Adds a `Range: bytes=start-end` header to future requests.
        public func setByteRange(start: Int, end: Int) {
            httpAPI.pointee.setByteRange.unsafelyUnwrapped(pointer, Int32(start), Int32(end))
        }

        /// The time to wait for incoming data, in milliseconds.
        public func setReadTimeout(milliseconds: Int) {
            httpAPI.pointee.setReadTimeout.unsafelyUnwrapped(pointer, Int32(milliseconds))
        }

        /// The size of the connection's read buffer, in bytes.
        public func setReadBufferSize(bytes: Int) {
            httpAPI.pointee.setReadBufferSize.unsafelyUnwrapped(pointer, Int32(bytes))
        }

        // MARK: Requests

        /// Sends a GET request for `path`. `headers` are raw header lines
        /// (e.g. "Accept: text/html\r\n").
        public func get(path: String, headers: String = "") throws(NetError) {
            let error = path.withPlaydateCString { cPath in
                headers.withPlaydateCString { cHeaders in
                    httpAPI.pointee.get.unsafelyUnwrapped(pointer, cPath, cHeaders, headers.utf8.count)
                }
            }
            try Network.check(error)
        }

        /// Sends a POST request for `path` with the given body.
        public func post(path: String, headers: String = "", body: [UInt8]) throws(NetError) {
            let error = path.withPlaydateCString { cPath in
                headers.withPlaydateCString { cHeaders in
                    body.withUnsafeBytes { bodyBuffer in
                        httpAPI.pointee.post.unsafelyUnwrapped(
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
                            httpAPI.pointee.query.unsafelyUnwrapped(
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
            Network.optionalError(httpAPI.pointee.getError.unsafelyUnwrapped(pointer))
        }

        /// The number of bytes read of the current response, and the total
        /// expected (0 if the response has no Content-Length).
        public var progress: (read: Int, total: Int) {
            var read: Int32 = 0, total: Int32 = 0
            httpAPI.pointee.getProgress.unsafelyUnwrapped(pointer, &read, &total)
            return (Int(read), Int(total))
        }

        /// The HTTP status code of the response.
        public var responseStatus: Int {
            Int(httpAPI.pointee.getResponseStatus.unsafelyUnwrapped(pointer))
        }

        /// The number of response bytes available to read.
        public var bytesAvailable: Int {
            Int(httpAPI.pointee.getBytesAvailable.unsafelyUnwrapped(pointer))
        }

        /// Reads up to `buffer.count` response bytes. Returns the number of
        /// bytes read.
        public func read(into buffer: UnsafeMutableRawBufferPointer) throws(NetError) -> Int {
            let result = httpAPI.pointee.read.unsafelyUnwrapped(pointer, buffer.baseAddress,
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
                httpAPI.pointee.read.unsafelyUnwrapped(pointer, buffer.baseAddress, UInt32(buffer.count))
            }
            if result < 0 {
                throw NetError(rawValue: result) ?? .unknown
            }
            bytes.removeLast(length - Int(result))
            return bytes
        }

        /// Closes the connection.
        public func close() {
            httpAPI.pointee.close.unsafelyUnwrapped(pointer)
        }

        // MARK: Callbacks

        /// Called for each header line as it arrives.
        public func setHeaderReceivedCallback(_ callback: ((HTTPConnection, _ key: String, _ value: String) -> Void)?) {
            headerReceivedCallback = callback
            if callback != nil {
                httpAPI.pointee.setHeaderReceivedCallback.unsafelyUnwrapped(pointer, { connection, key, value in
                    guard let wrapper = HTTPConnection.wrapper(for: connection),
                          let key = String(playdateCString: key),
                          let value = String(playdateCString: value) else { return }
                    wrapper.headerReceivedCallback?(wrapper, key, value)
                })
            } else {
                httpAPI.pointee.setHeaderReceivedCallback.unsafelyUnwrapped(pointer, nil)
            }
        }

        /// Called when all headers have been read.
        public func setHeadersReadCallback(_ callback: ((HTTPConnection) -> Void)?) {
            headersReadCallback = callback
            if callback != nil {
                httpAPI.pointee.setHeadersReadCallback.unsafelyUnwrapped(pointer, { connection in
                    guard let wrapper = HTTPConnection.wrapper(for: connection) else { return }
                    wrapper.headersReadCallback?(wrapper)
                })
            } else {
                httpAPI.pointee.setHeadersReadCallback.unsafelyUnwrapped(pointer, nil)
            }
        }

        /// Called when response data is available to read.
        public func setResponseCallback(_ callback: ((HTTPConnection) -> Void)?) {
            responseCallback = callback
            if callback != nil {
                httpAPI.pointee.setResponseCallback.unsafelyUnwrapped(pointer, { connection in
                    guard let wrapper = HTTPConnection.wrapper(for: connection) else { return }
                    wrapper.responseCallback?(wrapper)
                })
            } else {
                httpAPI.pointee.setResponseCallback.unsafelyUnwrapped(pointer, nil)
            }
        }

        /// Called when the request finishes.
        public func setRequestCompleteCallback(_ callback: ((HTTPConnection) -> Void)?) {
            requestCompleteCallback = callback
            if callback != nil {
                httpAPI.pointee.setRequestCompleteCallback.unsafelyUnwrapped(pointer, { connection in
                    guard let wrapper = HTTPConnection.wrapper(for: connection) else { return }
                    wrapper.requestCompleteCallback?(wrapper)
                })
            } else {
                httpAPI.pointee.setRequestCompleteCallback.unsafelyUnwrapped(pointer, nil)
            }
        }

        /// Called when the connection closes.
        public func setConnectionClosedCallback(_ callback: ((HTTPConnection) -> Void)?) {
            connectionClosedCallback = callback
            if callback != nil {
                httpAPI.pointee.setConnectionClosedCallback.unsafelyUnwrapped(pointer, { connection in
                    guard let wrapper = HTTPConnection.wrapper(for: connection) else { return }
                    wrapper.connectionClosedCallback?(wrapper)
                })
            } else {
                httpAPI.pointee.setConnectionClosedCallback.unsafelyUnwrapped(pointer, nil)
            }
        }
    }
}
