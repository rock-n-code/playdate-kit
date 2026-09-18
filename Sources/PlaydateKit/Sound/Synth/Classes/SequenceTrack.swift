internal import CPlaydate

extension Sound {
    /// Notes and control signals played on one instrument. Wraps `SequenceTrack`.
    /// Owns the control signals it returns; keeps an instrument set on it alive.
    public final class SequenceTrack {
        private static var api: UnsafePointer<playdate_sound_track> { Playdate.trackAPI.unsafelyUnwrapped }

        let pointer: OpaquePointer
        let isOwned: Bool
        private var retainedInstrument: Instrument?

        init(pointer: OpaquePointer, isOwned: Bool) {
            self.pointer = pointer
            self.isOwned = isOwned
        }

        public convenience init() {
            self.init(pointer: SequenceTrack.api.pointee.newTrack.unsafelyUnwrapped().unsafelyUnwrapped,
                      isOwned: true)
        }

        deinit {
            if isOwned {
                SequenceTrack.api.pointee.freeTrack.unsafelyUnwrapped(pointer)
            }
        }

        public var instrument: Instrument? {
            get {
                if let retainedInstrument { return retainedInstrument }
                guard let instrument = SequenceTrack.api.pointee.getInstrument.unsafelyUnwrapped(pointer) else {
                    return nil
                }
                return Instrument(pointer: instrument, isOwned: false)
            }
            set {
                retainedInstrument = newValue
                SequenceTrack.api.pointee.setInstrument.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        /// `length` is in steps.
        public func addNote(step: UInt32, length: UInt32, note: MIDINote, velocity: Float = 1) {
            SequenceTrack.api.pointee.addNoteEvent.unsafelyUnwrapped(pointer, step, length, note, velocity)
        }

        public func removeNote(step: UInt32, note: MIDINote) {
            SequenceTrack.api.pointee.removeNoteEvent.unsafelyUnwrapped(pointer, step, note)
        }

        public func clearNotes() {
            SequenceTrack.api.pointee.clearNotes.unsafelyUnwrapped(pointer)
        }

        /// In steps: where the last note ends.
        public var length: UInt32 {
            SequenceTrack.api.pointee.getLength.unsafelyUnwrapped(pointer)
        }

        /// The internal index of the first note at `step`.
        public func indexForStep(_ step: UInt32) -> Int {
            Int(SequenceTrack.api.pointee.getIndexForStep.unsafelyUnwrapped(pointer, step))
        }

        public func note(at index: Int) -> (step: UInt32, length: UInt32,
                                            note: MIDINote, velocity: Float)? {
            var step: UInt32 = 0, length: UInt32 = 0
            var note: MIDINote = 0
            var velocity: Float = 0
            guard SequenceTrack.api.pointee.getNoteAtIndex.unsafelyUnwrapped(
                pointer, Int32(index), &step, &length, &note, &velocity) != 0 else { return nil }
            return (step, length, note, velocity)
        }

        public var controlSignalCount: Int {
            Int(SequenceTrack.api.pointee.getControlSignalCount.unsafelyUnwrapped(pointer))
        }

        public func controlSignal(at index: Int) -> ControlSignal? {
            guard let signal = SequenceTrack.api.pointee.getControlSignal.unsafelyUnwrapped(
                pointer, Int32(index)) else { return nil }
            return ControlSignal(pointer: signal, isOwned: false)
        }

        /// If `create`, makes the signal for `controller` when it is missing.
        public func signalForController(_ controller: Int, create: Bool = false) -> ControlSignal? {
            guard let signal = SequenceTrack.api.pointee.getSignalForController.unsafelyUnwrapped(
                pointer, Int32(controller), create ? 1 : 0) else { return nil }
            return ControlSignal(pointer: signal, isOwned: false)
        }

        public func clearControlEvents() {
            SequenceTrack.api.pointee.clearControlEvents.unsafelyUnwrapped(pointer)
        }

        /// Max simultaneous notes; set only for tracks loaded from a MIDI file.
        public var polyphony: Int {
            Int(SequenceTrack.api.pointee.getPolyphony.unsafelyUnwrapped(pointer))
        }

        /// Voices playing in the track's instrument.
        public var activeVoiceCount: Int {
            Int(SequenceTrack.api.pointee.activeVoiceCount.unsafelyUnwrapped(pointer))
        }

        public func setMuted(_ muted: Bool) {
            SequenceTrack.api.pointee.setMuted.unsafelyUnwrapped(pointer, muted ? 1 : 0)
        }
    }
}
