internal import CPlaydate

extension Sound {
    /// An ADSR envelope signal. Wraps `PDSynthEnvelope`.
    public final class Envelope: SignalValue {
        private static var api: UnsafePointer<playdate_sound_envelope> { Playdate.envelopeAPI.unsafelyUnwrapped }

        /// `attack`, `decay`, and `release` are in seconds; `sustain` is 0...1.
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

        /// In seconds.
        public func setAttack(_ attack: Float) {
            Envelope.api.pointee.setAttack.unsafelyUnwrapped(pointer, attack)
        }

        /// In seconds.
        public func setDecay(_ decay: Float) {
            Envelope.api.pointee.setDecay.unsafelyUnwrapped(pointer, decay)
        }

        /// 0...1.
        public func setSustain(_ sustain: Float) {
            Envelope.api.pointee.setSustain.unsafelyUnwrapped(pointer, sustain)
        }

        /// In seconds.
        public func setRelease(_ release: Float) {
            Envelope.api.pointee.setRelease.unsafelyUnwrapped(pointer, release)
        }

        /// If `true`, retriggering before release stays in sustain instead of re-attacking.
        public func setLegato(_ flag: Bool) {
            Envelope.api.pointee.setLegato.unsafelyUnwrapped(pointer, flag ? 1 : 0)
        }

        /// If `true`, each note starts from 0 instead of the current value.
        public func setRetrigger(_ flag: Bool) {
            Envelope.api.pointee.setRetrigger.unsafelyUnwrapped(pointer, flag ? 1 : 0)
        }

        /// Segment shape, 0 (linear) to 1 (exponential).
        public func setCurvature(_ amount: Float) {
            Envelope.api.pointee.setCurvature.unsafelyUnwrapped(pointer, amount)
        }

        /// 1 (default) scales output by velocity; 0 ignores it.
        public func setVelocitySensitivity(_ sensitivity: Float) {
            Envelope.api.pointee.setVelocitySensitivity.unsafelyUnwrapped(pointer, sensitivity)
        }

        /// Rate scale by note: 1 below `start`, `scaling` above `end`, interpolated between.
        public func setRateScaling(_ scaling: Float, start: MIDINote, end: MIDINote) {
            Envelope.api.pointee.setRateScaling.unsafelyUnwrapped(pointer, scaling, start, end)
        }

        public var value: Float {
            Envelope.api.pointee.getValue.unsafelyUnwrapped(pointer)
        }
    }
}
