internal import CPlaydate

extension System {
    /// Battery and power supply state.
    public struct PowerStatus: OptionSet, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }

        /// The battery is charging.
        public static let charging = PowerStatus(rawValue: UInt32(kPDPowerStatusCharging.rawValue))
        /// Power is supplied over USB.
        public static let usb = PowerStatus(rawValue: UInt32(kPDPowerStatusUsb.rawValue))
        /// Power is supplied through the accessory screw terminals.
        public static let screws = PowerStatus(rawValue: UInt32(kPDPowerStatusScrews.rawValue))
    }
}
