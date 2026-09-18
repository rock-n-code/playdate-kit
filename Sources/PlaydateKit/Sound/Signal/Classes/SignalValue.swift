extension Sound {
    /// A value that can modulate a parameter. Wraps `PDSynthSignalValue`; base of
    /// `Signal`, `LFO`, `Envelope`, and `ControlSignal`. What it modulates keeps it
    /// alive; assigning `nil` to a modulator property clears it.
    public class SignalValue {
        let pointer: OpaquePointer
        let isOwned: Bool

        init(pointer: OpaquePointer, isOwned: Bool) {
            self.pointer = pointer
            self.isOwned = isOwned
        }

        /// Wraps a C API pointer without taking ownership.
        static func wrap(_ pointer: OpaquePointer?) -> SignalValue? {
            guard let pointer else { return nil }
            return SignalValue(pointer: pointer, isOwned: false)
        }
    }
}
