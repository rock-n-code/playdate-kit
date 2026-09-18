internal import CPlaydate

/// The cached `playdate->network->http` C API table.
private var httpAPI: UnsafePointer<playdate_http> { Playdate.httpAPI.unsafelyUnwrapped }

extension Network {
    /// An HTTP connection. Wraps `HTTPConnection`; methods throw `Network.NetError`.
    /// Callbacks don't retain it: keep it referenced until they fire, as `deinit`
    /// drops pending callbacks and releases the C connection.
    public final class HTTPConnection {
        let pointer: OpaquePointer

        var headerReceivedCallback: ((HTTPConnection, _ key: String, _ value: String) -> Void)?
        var headersReadCallback: ((HTTPConnection) -> Void)?
        var responseCallback: ((HTTPConnection) -> Void)?
        var requestCompleteCallback: ((HTTPConnection) -> Void)?
        var connectionClosedCallback: ((HTTPConnection) -> Void)?

        /// Asks to connect to `server` and its subdomains; call before `init`.
        /// `purpose` appears in the dialog; `completion` runs only if the reply is `.ask`.
        @discardableResult
        public static func requestAccess(server: String, port: Int = 443, useSSL: Bool = true,
                                         purpose: String? = nil,
                                         completion: @escaping (Bool) -> Void) -> AccessReply {
            Network.requestAccess(
                rawRequest: { httpAPI.pointee.requestAccess.unsafelyUnwrapped($0, $1, $2, $3, $4, $5) },
                server: server, port: port, useSSL: useSSL, purpose: purpose,
                completion: completion)
        }

        /// Sends nothing until a request. `nil` if access is denied or not yet granted.
        public init?(server: String, port: Int = 443, useSSL: Bool = true) {
            let pointer = server.withCString {
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

        /// Connect timeout, in ms.
        public func setConnectTimeout(milliseconds: Int) {
            httpAPI.pointee.setConnectTimeout.unsafelyUnwrapped(pointer, Int32(milliseconds))
        }

        /// Whether requests send `Connection: keep-alive`.
        public func setKeepAlive(_ keepAlive: Bool) {
            httpAPI.pointee.setKeepAlive.unsafelyUnwrapped(pointer, keepAlive)
        }

        /// Adds a `Range: bytes=start-end` header.
        public func setByteRange(start: Int, end: Int) {
            httpAPI.pointee.setByteRange.unsafelyUnwrapped(pointer, Int32(start), Int32(end))
        }

        /// How long `read` waits for data, in ms (default 1000).
        public func setReadTimeout(milliseconds: Int) {
            httpAPI.pointee.setReadTimeout.unsafelyUnwrapped(pointer, Int32(milliseconds))
        }

        /// Read buffer size, in bytes (default 64 KB).
        public func setReadBufferSize(bytes: Int) {
            httpAPI.pointee.setReadBufferSize.unsafelyUnwrapped(pointer, Int32(bytes))
        }

        // MARK: Requests

        /// GETs `path`, opening the connection if needed. `headers` are extra raw
        /// header lines (e.g. "Accept: text/html\r\n").
        public func get(path: String, headers: String = "") throws(NetError) {
            let error = path.withCString { cPath in
                headers.withCString { cHeaders in
                    httpAPI.pointee.get.unsafelyUnwrapped(pointer, cPath, cHeaders, headers.utf8.count)
                }
            }
            try Network.check(error)
        }

        /// POSTs `body` to `path`; otherwise like `get`.
        public func post(path: String, headers: String = "", body: [UInt8]) throws(NetError) {
            let error = path.withCString { cPath in
                headers.withCString { cHeaders in
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

        /// Sends a `method` request; otherwise like `post`.
        public func query(method: String, path: String, headers: String = "",
                          body: [UInt8] = []) throws(NetError) {
            let error = method.withCString { cMethod in
                path.withCString { cPath in
                    headers.withCString { cHeaders in
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

        /// The connection's last error, if any.
        public var error: NetError? {
            Network.optionalError(httpAPI.pointee.getError.unsafelyUnwrapped(pointer))
        }

        /// Response bytes read so far, and the total expected if known.
        public var progress: (read: Int, total: Int) {
            var read: Int32 = 0, total: Int32 = 0
            httpAPI.pointee.getProgress.unsafelyUnwrapped(pointer, &read, &total)
            return (Int(read), Int(total))
        }

        /// HTTP status code, valid once headers are parsed.
        public var responseStatus: Int {
            Int(httpAPI.pointee.getResponseStatus.unsafelyUnwrapped(pointer))
        }

        /// Response bytes available to read.
        public var bytesAvailable: Int {
            Int(httpAPI.pointee.getBytesAvailable.unsafelyUnwrapped(pointer))
        }

        /// Reads up to `buffer.count` bytes (capped by the read buffer size), waiting
        /// up to the read timeout. Returns the count read.
        public func read(into buffer: inout MutableSpan<UInt8>) throws(NetError) -> Int {
            let result = buffer.withUnsafeMutableBufferPointer { buffer in
                httpAPI.pointee.read.unsafelyUnwrapped(pointer, buffer.baseAddress, UInt32(buffer.count))
            }
            if result < 0 {
                throw NetError(rawValue: result) ?? .unknown
            }
            return Int(result)
        }

        /// Like `read(into:)`, returning the bytes read.
        public func read(length: Int) throws(NetError) -> [UInt8] {
            try [UInt8](capacity: length) { output throws(NetError) in
                let result = output.withUnsafeMutableBufferPointer { buffer, initializedCount in
                    let result = httpAPI.pointee.read.unsafelyUnwrapped(
                        pointer, buffer.baseAddress, UInt32(buffer.count))
                    initializedCount = max(Int(result), 0)
                    return result
                }
                if result < 0 {
                    throw NetError(rawValue: result) ?? .unknown
                }
            }
        }

        /// Closes the connection; it can be reused for another request.
        public func close() {
            httpAPI.pointee.close.unsafelyUnwrapped(pointer)
        }

        // MARK: Callbacks

        /// Called per response header line. `nil` removes it.
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

        /// Called once headers are parsed, making `responseStatus` and `progress` valid.
        /// `nil` removes it.
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

        /// Called when response data is available to read. `nil` removes it.
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

        /// Called when all data arrives (size known) or the request times out. `nil` removes it.
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

        /// Called when the server closes the connection. `nil` removes it.
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
