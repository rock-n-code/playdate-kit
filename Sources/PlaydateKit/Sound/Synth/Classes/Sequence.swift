internal import CPlaydate

extension Sound {
    /// A collection of tracks with tempo and loop control, playable from a
    /// MIDI file. Wraps `SoundSequence`.
    public final class Sequence {
        private static var api: UnsafePointer<playdate_sound_sequence> { Playdate.sequenceAPI.unsafelyUnwrapped }

        let pointer: OpaquePointer
        private var retainedTracks: [SequenceTrack] = []
        var finishCallback: ((Sequence) -> Void)?

        public init() {
            pointer = Sequence.api.pointee.newSequence.unsafelyUnwrapped().unsafelyUnwrapped
        }

        /// Creates a sequence and loads the MIDI file at `path`.
        public convenience init(midiFilePath: String) throws(PlaydateError) {
            self.init()
            try loadMIDIFile(path: midiFilePath)
        }

        deinit {
            Sequence.api.pointee.freeSequence.unsafelyUnwrapped(pointer)
        }

        public func loadMIDIFile(path: String) throws(PlaydateError) {
            let loaded = path.withPlaydateCString {
                Sequence.api.pointee.loadMIDIFile.unsafelyUnwrapped(pointer, $0) != 0
            }
            if !loaded {
                throw PlaydateError(message: "unable to load MIDI file: \(path)")
            }
        }

        /// Starts playback. `completion` is called when the sequence finishes.
        public func play(completion: ((Sequence) -> Void)? = nil) {
            finishCallback = completion
            if completion != nil {
                Sequence.api.pointee.play.unsafelyUnwrapped(pointer, { _, userdata in
                    guard let userdata else { return }
                    let sequence = Unmanaged<Sequence>.fromOpaque(userdata).takeUnretainedValue()
                    sequence.finishCallback?(sequence)
                }, Unmanaged.passUnretained(self).toOpaque())
            } else {
                Sequence.api.pointee.play.unsafelyUnwrapped(pointer, nil, nil)
            }
        }

        public func stop() {
            Sequence.api.pointee.stop.unsafelyUnwrapped(pointer)
        }

        public var isPlaying: Bool {
            Sequence.api.pointee.isPlaying.unsafelyUnwrapped(pointer) != 0
        }

        /// The playback position, in samples.
        public var time: UInt32 {
            get { Sequence.api.pointee.getTime.unsafelyUnwrapped(pointer) }
            set { Sequence.api.pointee.setTime.unsafelyUnwrapped(pointer, newValue) }
        }

        /// The tempo, in steps per second.
        public var tempo: Float {
            get { Sequence.api.pointee.getTempo.unsafelyUnwrapped(pointer) }
            set { Sequence.api.pointee.setTempo.unsafelyUnwrapped(pointer, newValue) }
        }

        /// The sequence's length in steps, including the tail of the last note.
        public var length: UInt32 {
            Sequence.api.pointee.getLength.unsafelyUnwrapped(pointer)
        }

        /// Loops the range `loopStart..<loopEnd` (steps) `loops` times while
        /// playing; 0 loops endlessly.
        public func setLoops(start: Int, end: Int, count: Int = 0) {
            Sequence.api.pointee.setLoops.unsafelyUnwrapped(pointer, Int32(start), Int32(end), Int32(count))
        }

        /// The current step, and the time offset (in samples) into that step.
        public var currentStep: (step: Int, timeOffset: Int) {
            var timeOffset: Int32 = 0
            let step = Sequence.api.pointee.getCurrentStep.unsafelyUnwrapped(pointer, &timeOffset)
            return (Int(step), Int(timeOffset))
        }

        /// Moves playback to the given step. If `playNotes` is `true`, notes
        /// at the position (that started before it) are played.
        public func setCurrentStep(_ step: Int, timeOffset: Int = 0, playNotes: Bool = false) {
            Sequence.api.pointee.setCurrentStep.unsafelyUnwrapped(pointer, Int32(step),
                                                          Int32(timeOffset), playNotes ? 1 : 0)
        }

        // MARK: Tracks

        public var trackCount: Int {
            Int(Sequence.api.pointee.getTrackCount.unsafelyUnwrapped(pointer))
        }

        /// Adds a new track to the sequence. The track is owned by the
        /// sequence.
        @discardableResult
        public func addTrack() -> SequenceTrack {
            let track = SequenceTrack(
                pointer: Sequence.api.pointee.addTrack.unsafelyUnwrapped(pointer).unsafelyUnwrapped,
                isOwned: false)
            retainedTracks.append(track)
            return track
        }

        /// The track at `index`. Owned by the sequence.
        public func track(at index: Int) -> SequenceTrack? {
            guard let track = Sequence.api.pointee.getTrackAtIndex.unsafelyUnwrapped(
                pointer, UInt32(index)) else { return nil }
            return SequenceTrack(pointer: track, isOwned: false)
        }

        /// Installs `track` at `index`.
        public func setTrack(_ track: SequenceTrack, at index: Int) {
            if !retainedTracks.contains(where: { $0 === track }) {
                retainedTracks.append(track)
            }
            Sequence.api.pointee.setTrackAtIndex.unsafelyUnwrapped(pointer, track.pointer, UInt32(index))
        }

        /// Releases every playing note in the sequence.
        public func allNotesOff() {
            Sequence.api.pointee.allNotesOff.unsafelyUnwrapped(pointer)
        }
    }
}
