extension Network {
    /// The device's wifi status.
    public enum WifiStatus: UInt32, Sendable {
        case notConnected = 0
        case connected = 1
        /// A connection was attempted but no configured access point was
        /// available.
        case notAvailable = 2
    }
}
