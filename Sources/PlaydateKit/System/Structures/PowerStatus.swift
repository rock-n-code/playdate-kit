internal import CPlaydate

extension System {
    /// Battery and power supply state.
    public struct PowerStatus: OptionSet, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }

        public static let charging = PowerStatus(rawValue: UInt32(kPDPowerStatusCharging.rawValue))
        public static let usb = PowerStatus(rawValue: UInt32(kPDPowerStatusUsb.rawValue))
        public static let screws = PowerStatus(rawValue: UInt32(kPDPowerStatusScrews.rawValue))
    }
}
