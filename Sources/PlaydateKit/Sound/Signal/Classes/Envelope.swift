internal import CPlaydate

extension Sound {
    /// An ADSR envelope signal. Wraps `PDSynthEnvelope`.
    public final class Envelope: SignalValue {
        private static var api: UnsafePointer<playdate_sound_envelope> { Playdate.envelopeAPI.unsafelyUnwrapped }

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
}
