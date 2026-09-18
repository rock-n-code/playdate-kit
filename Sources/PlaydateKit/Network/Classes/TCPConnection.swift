internal import CPlaydate

/// The cached `playdate->network->tcp` C API table.
private var tcpAPI: UnsafePointer<playdate_tcp> { Playdate.tcpAPI.unsafelyUnwrapped }

extension Network {
    /// A TCP connection. Wraps `TCPConnection`; methods throw `Network.NetError`.
    /// Callbacks don't retain it: keep it referenced until they fire, as `deinit`
    /// drops pending callbacks and releases the C connection.
    public final class TCPConnection {
        let pointer: OpaquePointer

        var openCompletion: ((TCPConnection, NetError?) -> Void)?
        var connectionClosedCallback: ((TCPConnection, NetError?) -> Void)?

        /// Asks to connect to `server`; call before `init`. `purpose` appears in
        /// the dialog; `completion` runs only if the reply is `.ask`.
        @discardableResult
        public static func requestAccess(server: String, port: Int, useSSL: Bool = true,
                                         purpose: String? = nil,
                                         completion: @escaping (Bool) -> Void) -> AccessReply {
            Network.requestAccess(
                rawRequest: { tcpAPI.pointee.requestAccess.unsafelyUnwrapped($0, $1, $2, $3, $4, $5) },
                server: server, port: port, useSSL: useSSL, purpose: purpose,
                completion: completion)
        }

        /// Does nothing until `open(_:)`. `nil` if access is denied or not yet granted.
        public init?(server: String, port: Int, useSSL: Bool = true) {
            let pointer = server.withCString {
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

        /// The connection's last error, if any.
        public var error: NetError? {
            Network.optionalError(tcpAPI.pointee.getError.unsafelyUnwrapped(pointer))
        }

        /// Connect timeout, in ms.
        public func setConnectTimeout(milliseconds: Int) {
            tcpAPI.pointee.setConnectTimeout.unsafelyUnwrapped(pointer, Int32(milliseconds))
        }

        /// Errors are thrown immediately or passed to `completion` (`nil` on success).
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

        /// Closes the connection; it can be reused.
        public func close() throws(NetError) {
            try Network.check(tcpAPI.pointee.close.unsafelyUnwrapped(pointer))
        }

        /// Called on close with the error, if any; `nil` removes it.
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

        /// How long `read` waits for data, in ms (default 1000).
        public func setReadTimeout(milliseconds: Int) {
            tcpAPI.pointee.setReadTimeout.unsafelyUnwrapped(pointer, Int32(milliseconds))
        }

        /// Read buffer size, in bytes (default 64 KB).
        public func setReadBufferSize(bytes: Int) {
            tcpAPI.pointee.setReadBufferSize.unsafelyUnwrapped(pointer, Int32(bytes))
        }

        /// Bytes available to read.
        public var bytesAvailable: Int {
            Int(tcpAPI.pointee.getBytesAvailable.unsafelyUnwrapped(pointer))
        }

        /// Written bytes not yet sent.
        public var sentBytesPending: Int {
            Int(tcpAPI.pointee.getSentBytesPending.unsafelyUnwrapped(pointer))
        }

        /// Reads up to `buffer.count` bytes within the read timeout; returns the count.
        public func read(into buffer: inout MutableSpan<UInt8>) throws(NetError) -> Int {
            let result = buffer.withUnsafeMutableBufferPointer { buffer in
                tcpAPI.pointee.read.unsafelyUnwrapped(pointer, buffer.baseAddress, buffer.count)
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
                    let result = tcpAPI.pointee.read.unsafelyUnwrapped(pointer, buffer.baseAddress, buffer.count)
                    initializedCount = max(Int(result), 0)
                    return result
                }
                if result < 0 {
                    throw NetError(rawValue: result) ?? .unknown
                }
            }
        }

        /// Queues `bytes`; returns the count handed to the network stack.
        @discardableResult
        public func write(_ bytes: Span<UInt8>) throws(NetError) -> Int {
            let result = bytes.withUnsafeBufferPointer { buffer in
                tcpAPI.pointee.write.unsafelyUnwrapped(pointer, buffer.baseAddress, buffer.count)
            }
            if result < 0 {
                throw NetError(rawValue: result) ?? .unknown
            }
            return Int(result)
        }

        /// Same as the `Span` overload.
        @discardableResult
        public func write(_ bytes: [UInt8]) throws(NetError) -> Int {
            try bytes.withUnsafeBufferPointer { buffer throws(NetError) in
                try write(buffer.span)
            }
        }
    }
}
