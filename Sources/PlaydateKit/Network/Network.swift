internal import CPlaydate

/// The cached `playdate->network` C API table.
private var networkAPI: UnsafePointer<playdate_network> { Playdate.networkAPI.unsafelyUnwrapped }

/// Wifi control, HTTP, and TCP. Throwing APIs here throw `Network.NetError`.
public enum Network {}

extension Network {
    static func check(_ error: PDNetErr) throws(NetError) {
        if error != NET_OK {
            throw NetError(error)
        }
    }

    static func optionalError(_ error: PDNetErr) -> NetError? {
        error == NET_OK ? nil : NetError(error)
    }

    /// The current wifi status; `.notConnected` for unrecognized C values.
    public static var status: WifiStatus {
        WifiStatus(rawValue: UInt32(networkAPI.pointee.getStatus.unsafelyUnwrapped().rawValue)) ?? .notConnected
    }

    /// Connects to the access point now. `completion` gets `nil` on success, in call order.
    public static func enable(completion: ((NetError?) -> Void)? = nil) {
        if let completion {
            enableCompletions.append(completion)
            networkAPI.pointee.setEnabled.unsafelyUnwrapped(true, { error in
                guard !Network.enableCompletions.isEmpty else { return }
                let completion = Network.enableCompletions.removeFirst()
                completion(Network.optionalError(error))
            })
        } else {
            networkAPI.pointee.setEnabled.unsafelyUnwrapped(true, nil)
        }
    }

    /// Turns wifi off now, not after the 30 s idle timeout.
    public static func disable() {
        // No callback: C documents it for enabling only, and a queued one would take
        // the next `enable` result.
        networkAPI.pointee.setEnabled.unsafelyUnwrapped(false, nil)
    }

    nonisolated(unsafe) private static var enableCompletions: [(NetError?) -> Void] = []

    /// Shared by HTTP and TCP. Retains `completion` until the C callback, which
    /// fires only for `.ask`.
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
        let reply = server.withCString { cServer in
            if let purpose {
                return purpose.withCString { cPurpose in
                    rawRequest(cServer, Int32(port), useSSL, cPurpose, trampoline, box.toOpaque())
                }
            } else {
                return rawRequest(cServer, Int32(port), useSSL, nil, trampoline, box.toOpaque())
            }
        }
        if reply != kAccessAsk {
            // Only `kAccessAsk` invokes the callback; balance the retain now.
            box.release()
        }
        return AccessReply(rawValue: UInt32(reply.rawValue)) ?? .ask
    }
}
