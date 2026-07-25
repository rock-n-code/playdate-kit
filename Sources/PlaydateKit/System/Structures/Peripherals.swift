internal import CPlaydate

extension System {
    /// Peripherals that can be enabled with `setPeripheralsEnabled(_:)`.
    public struct Peripherals: OptionSet, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }

        public static let none = Peripherals([])
        public static let accelerometer = Peripherals(rawValue: UInt32(kAccelerometer.rawValue))
        public static let all = Peripherals(rawValue: UInt32(kAllPeripherals.rawValue))
    }
}
