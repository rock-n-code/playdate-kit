internal import CPlaydate

extension Sound {
    /// A pool of synth voices for polyphonic playback. Wraps `PDSynthInstrument`.
    /// Keeps added voices alive.
    public final class Instrument {
        private static var api: UnsafePointer<playdate_sound_instrument> { Playdate.instrumentAPI.unsafelyUnwrapped }

        let pointer: OpaquePointer
        let isOwned: Bool
        private var retainedVoices: [Synth] = []

        init(pointer: OpaquePointer, isOwned: Bool) {
            self.pointer = pointer
            self.isOwned = isOwned
        }

        public convenience init() {
            self.init(pointer: Instrument.api.pointee.newInstrument.unsafelyUnwrapped().unsafelyUnwrapped,
                      isOwned: true)
        }

        deinit {
            if isOwned {
                Instrument.api.pointee.freeInstrument.unsafelyUnwrapped(pointer)
            }
        }

        /// Voices notes `rangeStart...rangeEnd`, transposed `transpose` half-steps on top of
        /// the instrument. Returns `false` if `synth` has another instrument or channel.
        @discardableResult
        public func addVoice(_ synth: Synth, rangeStart: MIDINote = 0, rangeEnd: MIDINote = 127,
                             transpose: Float = 0) -> Bool {
            let added = Instrument.api.pointee.addVoice.unsafelyUnwrapped(
                pointer, synth.pointer, rangeStart, rangeEnd, transpose) != 0
            if added, !retainedVoices.contains(where: { $0 === synth }) {
                retainedVoices.append(synth)
            }
            return added
        }

        /// Uses the next free voice, else the one released or playing longest. Arguments
        /// as in `Synth.playNote`. Returns the voice used, if any.
        @discardableResult
        public func playNote(frequency: Float, velocity: Float = 1,
                             length: Float? = nil, when: UInt32 = 0) -> Synth? {
            let synth = Instrument.api.pointee.playNote.unsafelyUnwrapped(
                pointer, frequency, velocity, length ?? -1, when)
            return voice(for: synth)
        }

        /// Like `playNote(frequency:velocity:length:when:)`; returns the voice used, if any.
        @discardableResult
        public func playMIDINote(_ note: MIDINote, velocity: Float = 1,
                                 length: Float? = nil, when: UInt32 = 0) -> Synth? {
            let synth = Instrument.api.pointee.playMIDINote.unsafelyUnwrapped(
                pointer, note, velocity, length ?? -1, when)
            return voice(for: synth)
        }

        private func voice(for pointer: OpaquePointer?) -> Synth? {
            guard let pointer else { return nil }
            if let voice = retainedVoices.first(where: { $0.pointer == pointer }) {
                return voice
            }
            return Synth(pointer: pointer, isOwned: false)
        }

        /// A fraction of the pitch bend range.
        public func setPitchBend(_ bend: Float) {
            Instrument.api.pointee.setPitchBend.unsafelyUnwrapped(pointer, bend)
        }

        /// The range of `setPitchBend(_:)`; default 12.
        public func setPitchBendRange(halfSteps: Float) {
            Instrument.api.pointee.setPitchBendRange.unsafelyUnwrapped(pointer, halfSteps)
        }

        /// Transposes all voices; fractional values allowed.
        public func setTranspose(halfSteps: Float) {
            Instrument.api.pointee.setTranspose.unsafelyUnwrapped(pointer, halfSteps)
        }

        /// Releases the voice playing `note` at audio-clock time `when`, or now if 0.
        public func noteOff(_ note: MIDINote, when: UInt32 = 0) {
            Instrument.api.pointee.noteOff.unsafelyUnwrapped(pointer, note, when)
        }

        /// Releases every voice at audio-clock time `when`, or now if 0.
        public func allNotesOff(when: UInt32 = 0) {
            Instrument.api.pointee.allNotesOff.unsafelyUnwrapped(pointer, when)
        }

        /// Left and right volume, 0...1.
        public var volume: (left: Float, right: Float) {
            get {
                var left: Float = 0, right: Float = 0
                Instrument.api.pointee.getVolume.unsafelyUnwrapped(pointer, &left, &right)
                return (left, right)
            }
            set { Instrument.api.pointee.setVolume.unsafelyUnwrapped(pointer, newValue.left, newValue.right) }
        }

        public var activeVoiceCount: Int {
            Int(Instrument.api.pointee.activeVoiceCount.unsafelyUnwrapped(pointer))
        }
    }
}
