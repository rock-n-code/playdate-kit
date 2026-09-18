internal import CPlaydate

extension System {
    /// A set of d-pad and A/B buttons. Wraps `PDButtons`.
    public struct Buttons: OptionSet, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        init(_ buttons: PDButtons) { self.rawValue = UInt32(buttons.rawValue) }
        var cValue: PDButtons { PDButtons(PDButtons.RawValue(rawValue)) }

        public static let left = Buttons(kButtonLeft)
        public static let right = Buttons(kButtonRight)
        public static let up = Buttons(kButtonUp)
        public static let down = Buttons(kButtonDown)
        public static let b = Buttons(kButtonB)
        public static let a = Buttons(kButtonA)
    }
}
