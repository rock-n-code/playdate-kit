internal import CPlaydate

extension Sound {
    /// A signal object; also provides custom signals driven by Swift
    /// callbacks. Wraps `PDSynthSignal`.
    public final class Signal: SignalValue {
        private static var api: UnsafePointer<playdate_sound_signal> { Playdate.signalAPI.unsafelyUnwrapped }

        private final class Box {
            let callbacks: Callbacks
            init(_ callbacks: Callbacks) { self.callbacks = callbacks }
        }

        /// Creates a signal driven by the given callbacks.
        public init(callbacks: Callbacks) {
            let box = Unmanaged.passRetained(Box(callbacks))
            let pointer = Signal.api.pointee.newSignal.unsafelyUnwrapped(
                { userdata, ioFrames, interpolationValue in
                    guard let userdata else { return 0 }
                    let box = Unmanaged<Box>.fromOpaque(userdata).takeUnretainedValue()
                    return box.callbacks.step(ioFrames, interpolationValue)
                },
                { userdata, note, velocity, length in
                    guard let userdata else { return }
                    let box = Unmanaged<Box>.fromOpaque(userdata).takeUnretainedValue()
                    box.callbacks.noteOn?(note, velocity, length)
                },
                { userdata, stopped, offset in
                    guard let userdata else { return }
                    let box = Unmanaged<Box>.fromOpaque(userdata).takeUnretainedValue()
                    box.callbacks.noteOff?(stopped != 0, Int(offset))
                },
                { userdata in
                    guard let userdata else { return }
                    Unmanaged<Box>.fromOpaque(userdata).release()
                },
                box.toOpaque())
            super.init(pointer: pointer.unsafelyUnwrapped, isOwned: true)
        }

        /// Creates a plain signal object wrapping an existing signal value,
        /// so it can be scaled and offset.
        public init(value: SignalValue) {
            let pointer = Signal.api.pointee.newSignalForValue.unsafelyUnwrapped(value.pointer)
            super.init(pointer: pointer.unsafelyUnwrapped, isOwned: true)
        }

        override init(pointer: OpaquePointer, isOwned: Bool) {
            super.init(pointer: pointer, isOwned: isOwned)
        }

        deinit {
            if isOwned {
                Signal.api.pointee.freeSignal.unsafelyUnwrapped(pointer)
            }
        }

        /// The signal's current value.
        public var value: Float {
            Signal.api.pointee.getValue.unsafelyUnwrapped(pointer)
        }

        /// Scales the signal's output.
        public func setValueScale(_ scale: Float) {
            Signal.api.pointee.setValueScale.unsafelyUnwrapped(pointer, scale)
        }

        /// Offsets the signal's output.
        public func setValueOffset(_ offset: Float) {
            Signal.api.pointee.setValueOffset.unsafelyUnwrapped(pointer, offset)
        }
    }
}
