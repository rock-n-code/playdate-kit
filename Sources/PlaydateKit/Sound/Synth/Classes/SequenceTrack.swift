internal import CPlaydate

extension Sound {
    /// A track of notes played by an instrument. Wraps `SequenceTrack`.
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

        /// The instrument that plays this track's notes.
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

        /// Adds a note starting at `step`, lasting `length` steps.
        public func addNote(step: UInt32, length: UInt32, note: MIDINote, velocity: Float = 1) {
            SequenceTrack.api.pointee.addNoteEvent.unsafelyUnwrapped(pointer, step, length, note, velocity)
        }

        public func removeNote(step: UInt32, note: MIDINote) {
            SequenceTrack.api.pointee.removeNoteEvent.unsafelyUnwrapped(pointer, step, note)
        }

        public func clearNotes() {
            SequenceTrack.api.pointee.clearNotes.unsafelyUnwrapped(pointer)
        }

        /// The track's length in steps, including the tail of the last note.
        public var length: UInt32 {
            SequenceTrack.api.pointee.getLength.unsafelyUnwrapped(pointer)
        }

        /// The index of the first note at or after `step`.
        public func indexForStep(_ step: UInt32) -> Int {
            Int(SequenceTrack.api.pointee.getIndexForStep.unsafelyUnwrapped(pointer, step))
        }

        /// The note at `index`, or `nil` if the index is out of range.
        public func note(at index: Int) -> (step: UInt32, length: UInt32,
                                            note: MIDINote, velocity: Float)? {
            var step: UInt32 = 0, length: UInt32 = 0
            var note: MIDINote = 0
            var velocity: Float = 0
            guard SequenceTrack.api.pointee.getNoteAtIndex.unsafelyUnwrapped(
                pointer, Int32(index), &step, &length, &note, &velocity) != 0 else { return nil }
            return (step, length, note, velocity)
        }

        /// The number of control signals on the track.
        public var controlSignalCount: Int {
            Int(SequenceTrack.api.pointee.getControlSignalCount.unsafelyUnwrapped(pointer))
        }

        /// The control signal at `index`. Owned by the track.
        public func controlSignal(at index: Int) -> ControlSignal? {
            guard let signal = SequenceTrack.api.pointee.getControlSignal.unsafelyUnwrapped(
                pointer, Int32(index)) else { return nil }
            return ControlSignal(pointer: signal, isOwned: false)
        }

        /// The control signal for MIDI controller `controller`, optionally
        /// creating it. Owned by the track.
        public func signalForController(_ controller: Int, create: Bool = false) -> ControlSignal? {
            guard let signal = SequenceTrack.api.pointee.getSignalForController.unsafelyUnwrapped(
                pointer, Int32(controller), create ? 1 : 0) else { return nil }
            return ControlSignal(pointer: signal, isOwned: false)
        }

        public func clearControlEvents() {
            SequenceTrack.api.pointee.clearControlEvents.unsafelyUnwrapped(pointer)
        }

        /// The maximum number of simultaneous notes in the track.
        public var polyphony: Int {
            Int(SequenceTrack.api.pointee.getPolyphony.unsafelyUnwrapped(pointer))
        }

        public var activeVoiceCount: Int {
            Int(SequenceTrack.api.pointee.activeVoiceCount.unsafelyUnwrapped(pointer))
        }

        public func setMuted(_ muted: Bool) {
            SequenceTrack.api.pointee.setMuted.unsafelyUnwrapped(pointer, muted ? 1 : 0)
        }
    }
}
