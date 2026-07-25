internal import CPlaydate

extension Sound {
    /// A signal whose values are set on a sequence timeline. Wraps
    /// `ControlSignal`.
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

        /// Removes all events from the signal's timeline.
        public func clearEvents() {
            ControlSignal.api.pointee.clearEvents.unsafelyUnwrapped(pointer)
        }

        /// Adds a value at `step` in the signal's timeline. If `interpolate`
        /// is `true`, the value ramps from the previous event.
        public func addEvent(step: Int, value: Float, interpolate: Bool = false) {
            ControlSignal.api.pointee.addEvent.unsafelyUnwrapped(pointer, Int32(step), value,
                                                         interpolate ? 1 : 0)
        }

        /// Removes the event at `step`, if any.
        public func removeEvent(step: Int) {
            ControlSignal.api.pointee.removeEvent.unsafelyUnwrapped(pointer, Int32(step))
        }

        /// The MIDI controller number for signals loaded from a MIDI file.
        public var midiControllerNumber: Int {
            Int(ControlSignal.api.pointee.getMIDIControllerNumber.unsafelyUnwrapped(pointer))
        }
    }
}
