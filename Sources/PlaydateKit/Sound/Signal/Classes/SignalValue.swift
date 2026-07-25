extension Sound {
    /// A value that can modulate a parameter. The base class of `Signal`,
    /// `LFO`, `Envelope`, and `ControlSignal`. Wraps `PDSynthSignalValue`.
    public class SignalValue {
        let pointer: OpaquePointer
        let isOwned: Bool

        init(pointer: OpaquePointer, isOwned: Bool) {
            self.pointer = pointer
            self.isOwned = isOwned
        }

        /// Wraps a signal value pointer returned by the OS (not owned).
        static func wrap(_ pointer: OpaquePointer?) -> SignalValue? {
            guard let pointer else { return nil }
            return SignalValue(pointer: pointer, isOwned: false)
        }
    }
}
