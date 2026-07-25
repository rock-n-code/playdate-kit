internal import CPlaydate

private var networkAPI: UnsafePointer<playdate_network> { Playdate.networkAPI.unsafelyUnwrapped }

/// The network API: wifi status, HTTP, and TCP.
public enum Network {}

extension Network {
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

    public static var status: WifiStatus {
        WifiStatus(rawValue: UInt32(networkAPI.pointee.getStatus.unsafelyUnwrapped().rawValue)) ?? .notConnected
    }

    /// Turns the wifi radio on or off. The completion receives `nil` on
    /// success. Completions of overlapping calls are delivered in call order.
    public static func setEnabled(_ enabled: Bool, completion: ((NetError?) -> Void)? = nil) {
        if let completion {
            setEnabledCompletions.append(completion)
            networkAPI.pointee.setEnabled.unsafelyUnwrapped(enabled, { error in
                guard !Network.setEnabledCompletions.isEmpty else { return }
                let completion = Network.setEnabledCompletions.removeFirst()
                completion(Network.optionalError(error))
            })
        } else {
            networkAPI.pointee.setEnabled.unsafelyUnwrapped(enabled, nil)
        }
    }

    nonisolated(unsafe) private static var setEnabledCompletions: [(NetError?) -> Void] = []

    /// Requests permission to connect to `server`. Shared by HTTP and TCP.
    static func requestAccess(
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
        return AccessReply(rawValue: UInt32(reply.rawValue)) ?? .ask
    }
}
