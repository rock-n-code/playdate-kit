internal import CPlaydate

private var tcpAPI: UnsafePointer<playdate_tcp> { Playdate.tcpAPI.unsafelyUnwrapped }

extension Network {
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
                rawRequest: { tcpAPI.pointee.requestAccess.unsafelyUnwrapped($0, $1, $2, $3, $4, $5) },
                server: server, port: port, useSSL: useSSL, purpose: purpose,
                completion: completion)
        }

        /// Creates a connection to `server`. Fails if access has not been
        /// granted. Call `open(_:)` to connect.
        public init?(server: String, port: Int, useSSL: Bool = true) {
            let pointer = server.withPlaydateCString {
                tcpAPI.pointee.newConnection.unsafelyUnwrapped($0, Int32(port), useSSL)
            }
            guard let pointer else { return nil }
            self.pointer = pointer
            tcpAPI.pointee.setUserdata.unsafelyUnwrapped(pointer, Unmanaged.passUnretained(self).toOpaque())
        }

        deinit {
            tcpAPI.pointee.setUserdata.unsafelyUnwrapped(pointer, nil)
            tcpAPI.pointee.release.unsafelyUnwrapped(pointer)
        }

        private static func wrapper(for pointer: OpaquePointer?) -> TCPConnection? {
            guard let pointer,
                  let userdata = tcpAPI.pointee.getUserdata.unsafelyUnwrapped(pointer) else { return nil }
            return Unmanaged<TCPConnection>.fromOpaque(userdata).takeUnretainedValue()
        }

        /// The last error on the connection, if any.
        public var error: NetError? {
            Network.optionalError(tcpAPI.pointee.getError.unsafelyUnwrapped(pointer))
        }

        /// The time to wait for the connection to open, in milliseconds.
        public func setConnectTimeout(milliseconds: Int) {
            tcpAPI.pointee.setConnectTimeout.unsafelyUnwrapped(pointer, Int32(milliseconds))
        }

        /// Opens the connection. The completion receives `nil` on success.
        public func open(_ completion: @escaping (TCPConnection, NetError?) -> Void) throws(NetError) {
            openCompletion = completion
            let error = tcpAPI.pointee.open.unsafelyUnwrapped(pointer, { connection, error, _ in
                guard let wrapper = TCPConnection.wrapper(for: connection) else { return }
                let completion = wrapper.openCompletion
                wrapper.openCompletion = nil
                completion?(wrapper, Network.optionalError(error))
            }, nil)
            try Network.check(error)
        }

        /// Closes the connection.
        public func close() throws(NetError) {
            try Network.check(tcpAPI.pointee.close.unsafelyUnwrapped(pointer))
        }

        /// Called when the connection closes, with the reason if it closed
        /// due to an error.
        public func setConnectionClosedCallback(_ callback: ((TCPConnection, NetError?) -> Void)?) {
            connectionClosedCallback = callback
            if callback != nil {
                tcpAPI.pointee.setConnectionClosedCallback.unsafelyUnwrapped(pointer, { connection, error in
                    guard let wrapper = TCPConnection.wrapper(for: connection) else { return }
                    wrapper.connectionClosedCallback?(wrapper, Network.optionalError(error))
                })
            } else {
                tcpAPI.pointee.setConnectionClosedCallback.unsafelyUnwrapped(pointer, nil)
            }
        }

        /// The time to wait for incoming data, in milliseconds.
        public func setReadTimeout(milliseconds: Int) {
            tcpAPI.pointee.setReadTimeout.unsafelyUnwrapped(pointer, Int32(milliseconds))
        }

        /// The size of the connection's read buffer, in bytes.
        public func setReadBufferSize(bytes: Int) {
            tcpAPI.pointee.setReadBufferSize.unsafelyUnwrapped(pointer, Int32(bytes))
        }

        /// The number of bytes available to read.
        public var bytesAvailable: Int {
            Int(tcpAPI.pointee.getBytesAvailable.unsafelyUnwrapped(pointer))
        }

        /// The number of written bytes not yet sent on the wire.
        public var sentBytesPending: Int {
            Int(tcpAPI.pointee.getSentBytesPending.unsafelyUnwrapped(pointer))
        }

        /// Reads up to `buffer.count` bytes, waiting up to the read timeout.
        /// Returns the number of bytes read.
        public func read(into buffer: UnsafeMutableRawBufferPointer) throws(NetError) -> Int {
            let result = tcpAPI.pointee.read.unsafelyUnwrapped(pointer, buffer.baseAddress, buffer.count)
            if result < 0 {
                throw NetError(rawValue: result) ?? .unknown
            }
            return Int(result)
        }

        /// Reads up to `length` bytes, waiting up to the read timeout.
        public func read(length: Int) throws(NetError) -> [UInt8] {
            var bytes = [UInt8](repeating: 0, count: length)
            let result = bytes.withUnsafeMutableBytes { buffer in
                tcpAPI.pointee.read.unsafelyUnwrapped(pointer, buffer.baseAddress, buffer.count)
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
            let result = tcpAPI.pointee.write.unsafelyUnwrapped(pointer, buffer.baseAddress, buffer.count)
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
                tcpAPI.pointee.write.unsafelyUnwrapped(pointer, buffer.baseAddress, buffer.count)
            }
            if result < 0 {
                throw NetError(rawValue: result) ?? .unknown
            }
            return Int(result)
        }
    }
}
