internal import CPlaydate

extension Sound {
    /// Values set at sequence steps, for automating parameters. Wraps `ControlSignal`.
    public final class ControlSignal: SignalValue {
        private static var api: UnsafePointer<playdate_control_signal> { Playdate.controlSignalAPI.unsafelyUnwrapped }

        public init() {
            let pointer = ControlSignal.api.pointee.newSignal.unsafelyUnwrapped()
            super.init(pointer: pointer.unsafelyUnwrapped, isOwned: true)
        }

        override init(pointer: OpaquePointer, isOwned: Bool) {
            super.init(pointer: pointer, isOwned: isOwned)
        }

        deinit {
            if isOwned {
                ControlSignal.api.pointee.freeSignal.unsafelyUnwrapped(pointer)
            }
        }

        public func clearEvents() {
            ControlSignal.api.pointee.clearEvents.unsafelyUnwrapped(pointer)
        }

        /// If `interpolate`, ramps to `value` from the previous event.
        public func addEvent(step: Int, value: Float, interpolate: Bool = false) {
            ControlSignal.api.pointee.addEvent.unsafelyUnwrapped(pointer, Int32(step), value,
                                                         interpolate ? 1 : 0)
        }

        public func removeEvent(step: Int) {
            ControlSignal.api.pointee.removeEvent.unsafelyUnwrapped(pointer, Int32(step))
        }

        /// For signals created by `Sequence.loadMIDIFile(path:)`.
        public var midiControllerNumber: Int {
            Int(ControlSignal.api.pointee.getMIDIControllerNumber.unsafelyUnwrapped(pointer))
        }
    }
}
