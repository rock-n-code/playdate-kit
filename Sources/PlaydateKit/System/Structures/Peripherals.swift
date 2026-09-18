internal import CPlaydate

extension System {
    /// Peripherals for `setPeripheralsEnabled(_:)`. Wraps `PDPeripherals`.
    public struct Peripherals: OptionSet, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }

        public static let none = Peripherals([])
        /// Disabled by default.
        public static let accelerometer = Peripherals(rawValue: UInt32(kAccelerometer.rawValue))
        public static let all = Peripherals(rawValue: UInt32(kAllPeripherals.rawValue))
    }
}
