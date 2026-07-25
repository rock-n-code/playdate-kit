//
//  SoundSignal.swift
//  Signal wrappers: PDSynthSignalValue, PDSynthSignal, PDSynthLFO,
//  PDSynthEnvelope, and ControlSignal.
//

internal import CPlaydate

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

    /// A signal object; also provides custom signals driven by Swift
    /// callbacks. Wraps `PDSynthSignal`.
    public final class Signal: SignalValue {
        private static var api: UnsafePointer<playdate_sound_signal> { snd.pointee.signal.unsafelyUnwrapped }

        /// Custom signal callbacks.
        public struct Callbacks {
            /// Returns the signal's value at the end of the current cycle.
            /// `ioFrames` is the number of frames until the cycle ends and
            /// may be lowered to interpolate toward `interpolationValue`.
            public var step: (_ ioFrames: UnsafeMutablePointer<Int32>?,
                              _ interpolationValue: UnsafeMutablePointer<Float>?) -> Float
            /// Called on note-on events. `length` is -1 for indefinite notes.
            public var noteOn: ((_ note: MIDINote, _ velocity: Float, _ length: Float) -> Void)?
            /// Called on note-off events. `stopped` is `false` when the note
            /// is released and `true` when it actually stops playing;
            /// `offset` is the frame offset within the current cycle.
            public var noteOff: ((_ stopped: Bool, _ offset: Int) -> Void)?

            public init(step: @escaping (_ ioFrames: UnsafeMutablePointer<Int32>?,
                                         _ interpolationValue: UnsafeMutablePointer<Float>?) -> Float,
                        noteOn: ((_ note: MIDINote, _ velocity: Float, _ length: Float) -> Void)? = nil,
                        noteOff: ((_ stopped: Bool, _ offset: Int) -> Void)? = nil) {
                self.step = step
                self.noteOn = noteOn
                self.noteOff = noteOff
            }
        }

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

    // MARK: - LFO

    /// A low-frequency oscillator signal. Wraps `PDSynthLFO`.
    public final class LFO: SignalValue {
        private static var api: UnsafePointer<playdate_sound_lfo> { snd.pointee.lfo.unsafelyUnwrapped }

        /// The oscillator's waveform.
        public enum Shape: UInt32, Sendable {
            case square = 0
            case triangle = 1
            case sine = 2
            case sampleAndHold = 3
            case sawtoothUp = 4
            case sawtoothDown = 5
            case arpeggiator = 6
            case function = 7

            var cValue: LFOType { LFOType(LFOType.RawValue(rawValue)) }
        }

        var function: ((LFO) -> Float)?

        public init(shape: Shape = .sine) {
            let pointer = LFO.api.pointee.newLFO.unsafelyUnwrapped(shape.cValue)
            super.init(pointer: pointer.unsafelyUnwrapped, isOwned: true)
        }

        deinit {
            if isOwned {
                LFO.api.pointee.freeLFO.unsafelyUnwrapped(pointer)
            }
        }

        public func setShape(_ shape: Shape) {
            LFO.api.pointee.setType.unsafelyUnwrapped(pointer, shape.cValue)
        }

        /// The LFO rate, in cycles per second.
        public func setRate(_ rate: Float) {
            LFO.api.pointee.setRate.unsafelyUnwrapped(pointer, rate)
        }

        /// The current phase, 0...1.
        public func setPhase(_ phase: Float) {
            LFO.api.pointee.setPhase.unsafelyUnwrapped(pointer, phase)
        }

        /// The phase the LFO starts at when a note starts, 0...1.
        public func setStartPhase(_ phase: Float) {
            LFO.api.pointee.setStartPhase.unsafelyUnwrapped(pointer, phase)
        }

        /// The center value of the LFO output.
        public func setCenter(_ center: Float) {
            LFO.api.pointee.setCenter.unsafelyUnwrapped(pointer, center)
        }

        /// The amplitude of the LFO around its center.
        public func setDepth(_ depth: Float) {
            LFO.api.pointee.setDepth.unsafelyUnwrapped(pointer, depth)
        }

        /// For `.arpeggiator` LFOs: the sequence of values (in half-steps)
        /// to step through.
        public func setArpeggiation(_ steps: [Float]) {
            var steps = steps
            steps.withUnsafeMutableBufferPointer { buffer in
                LFO.api.pointee.setArpeggiation.unsafelyUnwrapped(pointer, Int32(buffer.count),
                                                          buffer.baseAddress)
            }
        }

        /// For `.function` LFOs: the Swift function providing the value. If
        /// `interpolate` is `true`, values are interpolated between calls.
        public func setFunction(interpolate: Bool = false, _ function: @escaping (LFO) -> Float) {
            self.function = function
            LFO.api.pointee.setFunction.unsafelyUnwrapped(pointer, { _, userdata in
                guard let userdata else { return 0 }
                let lfo = Unmanaged<LFO>.fromOpaque(userdata).takeUnretainedValue()
                return lfo.function?(lfo) ?? 0
            }, Unmanaged.passUnretained(self).toOpaque(), interpolate ? 1 : 0)
        }

        /// Waits `holdoff` seconds after a note starts, then ramps the LFO
        /// depth up over `rampTime` seconds.
        public func setDelay(holdoff: Float, rampTime: Float) {
            LFO.api.pointee.setDelay.unsafelyUnwrapped(pointer, holdoff, rampTime)
        }

        /// Whether the LFO phase restarts on every new note.
        public func setRetrigger(_ flag: Bool) {
            LFO.api.pointee.setRetrigger.unsafelyUnwrapped(pointer, flag ? 1 : 0)
        }

        /// When `true`, the LFO runs globally instead of per-note.
        public func setGlobal(_ global: Bool) {
            LFO.api.pointee.setGlobal.unsafelyUnwrapped(pointer, global ? 1 : 0)
        }

        /// Seeds the random number generator used by `.sampleAndHold` LFOs.
        public func setRandomSeed(_ seed: UInt16) {
            LFO.api.pointee.setRandomSeed.unsafelyUnwrapped(pointer, seed)
        }

        public var value: Float {
            LFO.api.pointee.getValue.unsafelyUnwrapped(pointer)
        }
    }

    // MARK: - Envelope

    /// An ADSR envelope signal. Wraps `PDSynthEnvelope`.
    public final class Envelope: SignalValue {
        private static var api: UnsafePointer<playdate_sound_envelope> { snd.pointee.envelope.unsafelyUnwrapped }

        /// Creates an envelope with the given attack and decay times
        /// (seconds), sustain level (0...1), and release time (seconds).
        public init(attack: Float = 0, decay: Float = 0, sustain: Float = 1, release: Float = 0) {
            let pointer = Envelope.api.pointee.newEnvelope.unsafelyUnwrapped(attack, decay, sustain, release)
            super.init(pointer: pointer.unsafelyUnwrapped, isOwned: true)
        }

        override init(pointer: OpaquePointer, isOwned: Bool) {
            super.init(pointer: pointer, isOwned: isOwned)
        }

        deinit {
            if isOwned {
                Envelope.api.pointee.freeEnvelope.unsafelyUnwrapped(pointer)
            }
        }

        public func setAttack(_ attack: Float) {
            Envelope.api.pointee.setAttack.unsafelyUnwrapped(pointer, attack)
        }

        public func setDecay(_ decay: Float) {
            Envelope.api.pointee.setDecay.unsafelyUnwrapped(pointer, decay)
        }

        public func setSustain(_ sustain: Float) {
            Envelope.api.pointee.setSustain.unsafelyUnwrapped(pointer, sustain)
        }

        public func setRelease(_ release: Float) {
            Envelope.api.pointee.setRelease.unsafelyUnwrapped(pointer, release)
        }

        /// When `true`, a new note while a note is playing does not restart
        /// the envelope.
        public func setLegato(_ flag: Bool) {
            Envelope.api.pointee.setLegato.unsafelyUnwrapped(pointer, flag ? 1 : 0)
        }

        /// When `true`, a new note restarts the envelope from zero instead of
        /// its current value.
        public func setRetrigger(_ flag: Bool) {
            Envelope.api.pointee.setRetrigger.unsafelyUnwrapped(pointer, flag ? 1 : 0)
        }

        /// Bends the envelope's segments: 0 is linear, 1 is maximum curvature.
        public func setCurvature(_ amount: Float) {
            Envelope.api.pointee.setCurvature.unsafelyUnwrapped(pointer, amount)
        }

        /// How much note velocity scales the envelope's output.
        public func setVelocitySensitivity(_ sensitivity: Float) {
            Envelope.api.pointee.setVelocitySensitivity.unsafelyUnwrapped(pointer, sensitivity)
        }

        /// Scales the envelope's rate by note: notes above `start` play the
        /// envelope faster (up to `scaling` at `end` and beyond).
        public func setRateScaling(_ scaling: Float, start: MIDINote, end: MIDINote) {
            Envelope.api.pointee.setRateScaling.unsafelyUnwrapped(pointer, scaling, start, end)
        }

        public var value: Float {
            Envelope.api.pointee.getValue.unsafelyUnwrapped(pointer)
        }
    }

    // MARK: - ControlSignal

    /// A signal whose values are set on a sequence timeline. Wraps
    /// `ControlSignal`.
    public final class ControlSignal: SignalValue {
        private static var api: UnsafePointer<playdate_control_signal> { snd.pointee.controlsignal.unsafelyUnwrapped }

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

        /// Adds a value at `step` in the signal's timeline. If `interpolate`
        /// is `true`, the value ramps from the previous event.
        public func addEvent(step: Int, value: Float, interpolate: Bool = false) {
            ControlSignal.api.pointee.addEvent.unsafelyUnwrapped(pointer, Int32(step), value,
                                                         interpolate ? 1 : 0)
        }

        public func removeEvent(step: Int) {
            ControlSignal.api.pointee.removeEvent.unsafelyUnwrapped(pointer, Int32(step))
        }

        /// The MIDI controller number for signals loaded from a MIDI file.
        public var midiControllerNumber: Int {
            Int(ControlSignal.api.pointee.getMIDIControllerNumber.unsafelyUnwrapped(pointer))
        }
    }
}
