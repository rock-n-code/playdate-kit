internal import CPlaydate

extension Sound {
    /// Tracks played at a shared tempo. Wraps `SoundSequence`.
    /// Owns, or keeps alive, every track it returns or is given.
    public final class Sequence {
        private static var api: UnsafePointer<playdate_sound_sequence> { Playdate.sequenceAPI.unsafelyUnwrapped }

        let pointer: OpaquePointer
        private var retainedTracks: [SequenceTrack] = []
        var finishCallback: ((Sequence) -> Void)?

        public init() {
            pointer = Sequence.api.pointee.newSequence.unsafelyUnwrapped().unsafelyUnwrapped
        }

        public convenience init(path: String) throws(PlaydateError) {
            self.init()
            try loadMIDIFile(path: path)
        }

        deinit {
            Sequence.api.pointee.freeSequence.unsafelyUnwrapped(pointer)
        }

        public func loadMIDIFile(path: String) throws(PlaydateError) {
            let loaded = path.withCString {
                Sequence.api.pointee.loadMIDIFile.unsafelyUnwrapped(pointer, $0) != 0
            }
            if !loaded {
                throw PlaydateError(message: "unable to load MIDI file: \(path)")
            }
        }

        /// `completion` is called when the sequence finishes.
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

        /// The playback position, in samples (not steps).
        public var time: UInt32 {
            get { Sequence.api.pointee.getTime.unsafelyUnwrapped(pointer) }
            set { Sequence.api.pointee.setTime.unsafelyUnwrapped(pointer, newValue) }
        }

        /// In steps per second.
        public var tempo: Float {
            get { Sequence.api.pointee.getTempo.unsafelyUnwrapped(pointer) }
            set { Sequence.api.pointee.setTempo.unsafelyUnwrapped(pointer, newValue) }
        }

        /// The length of the longest track, in steps.
        public var length: UInt32 {
            Sequence.api.pointee.getLength.unsafelyUnwrapped(pointer)
        }

        /// Loops steps `start` to `end` `count` times; 0 loops forever.
        public func setLoops(start: Int, end: Int, count: Int = 0) {
            Sequence.api.pointee.setLoops.unsafelyUnwrapped(pointer, Int32(start), Int32(end), Int32(count))
        }

        /// `timeOffset` is in samples.
        public var currentStep: (step: Int, timeOffset: Int) {
            var timeOffset: Int32 = 0
            let step = Sequence.api.pointee.getCurrentStep.unsafelyUnwrapped(pointer, &timeOffset)
            return (Int(step), Int(timeOffset))
        }

        /// `timeOffset` is in samples. If `playNotes`, plays the notes at `step`
        /// (ignoring `timeOffset`).
        public func setCurrentStep(_ step: Int, timeOffset: Int = 0, playNotes: Bool = false) {
            Sequence.api.pointee.setCurrentStep.unsafelyUnwrapped(pointer, Int32(step),
                                                          Int32(timeOffset), playNotes ? 1 : 0)
        }

        // MARK: Tracks

        public var trackCount: Int {
            Int(Sequence.api.pointee.getTrackCount.unsafelyUnwrapped(pointer))
        }

        @discardableResult
        public func addTrack() -> SequenceTrack {
            let track = SequenceTrack(
                pointer: Sequence.api.pointee.addTrack.unsafelyUnwrapped(pointer).unsafelyUnwrapped,
                isOwned: false)
            retainedTracks.append(track)
            return track
        }

        public func track(at index: Int) -> SequenceTrack? {
            guard let track = Sequence.api.pointee.getTrackAtIndex.unsafelyUnwrapped(
                pointer, UInt32(index)) else { return nil }
            return SequenceTrack(pointer: track, isOwned: false)
        }

        public func setTrack(_ track: SequenceTrack, at index: Int) {
            if !retainedTracks.contains(where: { $0 === track }) {
                retainedTracks.append(track)
            }
            Sequence.api.pointee.setTrackAtIndex.unsafelyUnwrapped(pointer, track.pointer, UInt32(index))
        }

        public func allNotesOff() {
            Sequence.api.pointee.allNotesOff.unsafelyUnwrapped(pointer)
        }
    }
}
