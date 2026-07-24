//
//  SoundSynth.swift
//  Synth, Instrument, SequenceTrack, and Sequence wrappers.
//

internal import CPlaydate

extension Playdate.Sound {
    /// A synthesizer voice. Wraps `PDSynth`.
    public final class Synth: Source {
        private static var api: playdate_sound_synth { snd.synth.pointee }

        /// The synth's waveform.
        public enum Waveform: UInt32, Sendable {
            case square = 0
            case triangle = 1
            case sine = 2
            case noise = 3
            case sawtooth = 4
            case poPhase = 5
            case poDigital = 6
            case poVosim = 7

            var cValue: SoundWaveform { SoundWaveform(rawValue) }
        }

        /// Custom generator callbacks. Samples are in signed Q8.24 format.
        public struct Generator {
            /// Renders up to 256 sample frames into `left` (and `right` for
            /// stereo generators). `rate` is the per-frame phase step in
            /// Q0.32 format and `drate` its per-frame change. Returns the
            /// number of frames rendered.
            public var render: (_ left: UnsafeMutableBufferPointer<Int32>,
                                _ right: UnsafeMutableBufferPointer<Int32>?,
                                _ rate: UInt32, _ drate: Int32) -> Int
            /// Called when a note starts. `length` is -1 for indefinite notes.
            public var noteOn: ((_ note: MIDINote, _ velocity: Float, _ length: Float) -> Void)?
            /// Called when a note is released (`stop == false`) or stopped
            /// (`stop == true`).
            public var release: ((_ stop: Bool) -> Void)?
            /// Sets a generator parameter. Returns `true` if the parameter is
            /// valid.
            public var setParameter: ((_ parameter: Int, _ value: Float) -> Bool)?

            public init(render: @escaping (_ left: UnsafeMutableBufferPointer<Int32>,
                                           _ right: UnsafeMutableBufferPointer<Int32>?,
                                           _ rate: UInt32, _ drate: Int32) -> Int,
                        noteOn: ((_ note: MIDINote, _ velocity: Float, _ length: Float) -> Void)? = nil,
                        release: ((_ stop: Bool) -> Void)? = nil,
                        setParameter: ((_ parameter: Int, _ value: Float) -> Bool)? = nil) {
                self.render = render
                self.noteOn = noteOn
                self.release = release
                self.setParameter = setParameter
            }
        }

        private final class GeneratorBox {
            let generator: Generator
            let stereo: Bool
            init(_ generator: Generator, stereo: Bool) {
                self.generator = generator
                self.stereo = stereo
            }
        }

        private var retainedSample: AudioSample?
        private var retainedModulators: [SignalValue] = []

        override init(pointer: OpaquePointer?, isOwned: Bool) {
            super.init(pointer: pointer, isOwned: isOwned)
        }

        public convenience init() {
            self.init(pointer: Synth.api.newSynth.unsafelyUnwrapped().unsafelyUnwrapped,
                      isOwned: true)
        }

        public convenience init(waveform: Waveform) {
            self.init()
            setWaveform(waveform)
        }

        deinit {
            if isOwned {
                Synth.api.freeSynth.unsafelyUnwrapped(pointer)
            }
        }

        /// Copies the synth (and its generator, if any).
        public func copy() -> Synth {
            Synth(pointer: Synth.api.copy.unsafelyUnwrapped(pointer).unsafelyUnwrapped,
                  isOwned: true)
        }

        // MARK: Sound generation

        public func setWaveform(_ waveform: Waveform) {
            Synth.api.setWaveform.unsafelyUnwrapped(pointer, waveform.cValue)
        }

        /// Plays a sample instead of a waveform. A nonzero sustain range
        /// loops that part of the sample while the note is held.
        public func setSample(_ sample: AudioSample, sustainStart: UInt32 = 0, sustainEnd: UInt32 = 0) {
            retainedSample = sample
            Synth.api.setSample.unsafelyUnwrapped(pointer, sample.pointer, sustainStart, sustainEnd)
        }

        /// Uses a wavetable for the synth. `log2size` is the base-2 log of
        /// each waveform's size (e.g. 8 for 256 samples).
        public func setWavetable(_ sample: AudioSample, log2size: Int,
                                 columns: Int, rows: Int) throws(Playdate.Error) {
            retainedSample = sample
            guard Synth.api.setWavetable.unsafelyUnwrapped(
                pointer, sample.pointer, Int32(log2size), Int32(columns), Int32(rows)) != 0 else {
                throw Playdate.Error(message: "invalid wavetable dimensions")
            }
        }

        /// Provides audio via custom Swift callbacks.
        public func setGenerator(stereo: Bool, _ generator: Generator) {
            let box = Unmanaged.passRetained(GeneratorBox(generator, stereo: stereo))
            Synth.api.setGenerator.unsafelyUnwrapped(
                pointer, stereo ? 1 : 0,
                { userdata, left, right, nsamples, rate, drate in
                    guard let userdata, let left else { return 0 }
                    let box = Unmanaged<GeneratorBox>.fromOpaque(userdata).takeUnretainedValue()
                    let leftBuffer = UnsafeMutableBufferPointer(start: left, count: Int(nsamples))
                    let rightBuffer = right.map { UnsafeMutableBufferPointer(start: $0, count: Int(nsamples)) }
                    return Int32(box.generator.render(leftBuffer, rightBuffer, rate, drate))
                },
                { userdata, note, velocity, length in
                    guard let userdata else { return }
                    let box = Unmanaged<GeneratorBox>.fromOpaque(userdata).takeUnretainedValue()
                    box.generator.noteOn?(note, velocity, length)
                },
                { userdata, stop in
                    guard let userdata else { return }
                    let box = Unmanaged<GeneratorBox>.fromOpaque(userdata).takeUnretainedValue()
                    box.generator.release?(stop != 0)
                },
                { userdata, parameter, value in
                    guard let userdata else { return 0 }
                    let box = Unmanaged<GeneratorBox>.fromOpaque(userdata).takeUnretainedValue()
                    return box.generator.setParameter?(Int(parameter), value) == true ? 1 : 0
                },
                { userdata in
                    guard let userdata else { return }
                    Unmanaged<GeneratorBox>.fromOpaque(userdata).release()
                },
                { userdata in
                    guard let userdata else { return nil }
                    let box = Unmanaged<GeneratorBox>.fromOpaque(userdata).takeUnretainedValue()
                    return Unmanaged.passRetained(GeneratorBox(box.generator, stereo: box.stereo)).toOpaque()
                },
                box.toOpaque())
        }

        // MARK: Envelope

        public func setAttackTime(_ attack: Float) {
            Synth.api.setAttackTime.unsafelyUnwrapped(pointer, attack)
        }

        public func setDecayTime(_ decay: Float) {
            Synth.api.setDecayTime.unsafelyUnwrapped(pointer, decay)
        }

        public func setSustainLevel(_ sustain: Float) {
            Synth.api.setSustainLevel.unsafelyUnwrapped(pointer, sustain)
        }

        public func setReleaseTime(_ release: Float) {
            Synth.api.setReleaseTime.unsafelyUnwrapped(pointer, release)
        }

        /// The synth's amplitude envelope. Owned by the synth.
        public var envelope: Envelope? {
            guard let envelope = Synth.api.getEnvelope.unsafelyUnwrapped(pointer) else { return nil }
            return Envelope(pointer: envelope, isOwned: false)
        }

        /// Clears the synth's envelope so it plays at constant volume.
        public func clearEnvelope() {
            Synth.api.clearEnvelope.unsafelyUnwrapped(pointer)
        }

        // MARK: Modulation

        /// Transposes played notes by `halfSteps` (fractional values allowed).
        public func setTranspose(_ halfSteps: Float) {
            Synth.api.setTranspose.unsafelyUnwrapped(pointer, halfSteps)
        }

        public var frequencyModulator: SignalValue? {
            get { SignalValue.wrap(Synth.api.getFrequencyModulator.unsafelyUnwrapped(pointer)) }
            set {
                retain(newValue)
                Synth.api.setFrequencyModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        public var amplitudeModulator: SignalValue? {
            get { SignalValue.wrap(Synth.api.getAmplitudeModulator.unsafelyUnwrapped(pointer)) }
            set {
                retain(newValue)
                Synth.api.setAmplitudeModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        /// The number of parameters the synth's generator supports.
        public var parameterCount: Int {
            Int(Synth.api.getParameterCount.unsafelyUnwrapped(pointer))
        }

        /// Sets a generator parameter. Returns `false` if the parameter is
        /// invalid.
        @discardableResult
        public func setParameter(_ parameter: Int, value: Float) -> Bool {
            Synth.api.setParameter.unsafelyUnwrapped(pointer, Int32(parameter), value) != 0
        }

        public func setParameterModulator(_ parameter: Int, _ modulator: SignalValue?) {
            retain(modulator)
            Synth.api.setParameterModulator.unsafelyUnwrapped(pointer, Int32(parameter),
                                                              modulator?.pointer)
        }

        public func parameterModulator(_ parameter: Int) -> SignalValue? {
            SignalValue.wrap(Synth.api.getParameterModulator.unsafelyUnwrapped(pointer, Int32(parameter)))
        }

        private func retain(_ modulator: SignalValue?) {
            if let modulator, !retainedModulators.contains(where: { $0 === modulator }) {
                retainedModulators.append(modulator)
            }
        }

        // MARK: Playing

        /// Plays a note at `frequency` Hz. `length` is in seconds; `nil`
        /// plays until `noteOff()`. `when` is the audio-clock time to start,
        /// or 0 for immediately.
        public func playNote(frequency: Float, velocity: Float = 1,
                             length: Float? = nil, when: UInt32 = 0) {
            Synth.api.playNote.unsafelyUnwrapped(pointer, frequency, velocity, length ?? -1, when)
        }

        /// Plays a MIDI note, where 60 is middle C.
        public func playMIDINote(_ note: MIDINote, velocity: Float = 1,
                                 length: Float? = nil, when: UInt32 = 0) {
            Synth.api.playMIDINote.unsafelyUnwrapped(pointer, note, velocity, length ?? -1, when)
        }

        /// Releases the playing note at time `when`, or immediately if 0.
        public func noteOff(when: UInt32 = 0) {
            Synth.api.noteOff.unsafelyUnwrapped(pointer, when)
        }

        /// Stops the synth immediately, without playing the release phase.
        public func stop() {
            Synth.api.stop.unsafelyUnwrapped(pointer)
        }
    }

    // MARK: - Instrument

    /// A bank of synth voices for playing a sequence track. Wraps
    /// `PDSynthInstrument`.
    public final class Instrument {
        private static var api: playdate_sound_instrument { snd.instrument.pointee }

        let pointer: OpaquePointer
        let isOwned: Bool
        private var retainedVoices: [Synth] = []

        init(pointer: OpaquePointer, isOwned: Bool) {
            self.pointer = pointer
            self.isOwned = isOwned
        }

        public convenience init() {
            self.init(pointer: Instrument.api.newInstrument.unsafelyUnwrapped().unsafelyUnwrapped,
                      isOwned: true)
        }

        deinit {
            if isOwned {
                Instrument.api.freeInstrument.unsafelyUnwrapped(pointer)
            }
        }

        /// Adds a voice to the instrument, handling notes in
        /// `rangeStart...rangeEnd` (0...127 handles all notes), transposed by
        /// `transpose` half-steps.
        @discardableResult
        public func addVoice(_ synth: Synth, rangeStart: MIDINote = 0, rangeEnd: MIDINote = 127,
                             transpose: Float = 0) -> Bool {
            let added = Instrument.api.addVoice.unsafelyUnwrapped(
                pointer, synth.pointer, rangeStart, rangeEnd, transpose) != 0
            if added, !retainedVoices.contains(where: { $0 === synth }) {
                retainedVoices.append(synth)
            }
            return added
        }

        /// Plays a note at `frequency` Hz on an available voice. Returns the
        /// synth used, if any.
        @discardableResult
        public func playNote(frequency: Float, velocity: Float = 1,
                             length: Float? = nil, when: UInt32 = 0) -> Synth? {
            let synth = Instrument.api.playNote.unsafelyUnwrapped(
                pointer, frequency, velocity, length ?? -1, when)
            return voice(for: synth)
        }

        /// Plays a MIDI note on an available voice. Returns the synth used.
        @discardableResult
        public func playMIDINote(_ note: MIDINote, velocity: Float = 1,
                                 length: Float? = nil, when: UInt32 = 0) -> Synth? {
            let synth = Instrument.api.playMIDINote.unsafelyUnwrapped(
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

        /// Bends played notes by `bend` × the pitch bend range.
        public func setPitchBend(_ bend: Float) {
            Instrument.api.setPitchBend.unsafelyUnwrapped(pointer, bend)
        }

        public func setPitchBendRange(halfSteps: Float) {
            Instrument.api.setPitchBendRange.unsafelyUnwrapped(pointer, halfSteps)
        }

        public func setTranspose(halfSteps: Float) {
            Instrument.api.setTranspose.unsafelyUnwrapped(pointer, halfSteps)
        }

        /// Releases the voice playing `note` at time `when` (0 = now).
        public func noteOff(_ note: MIDINote, when: UInt32 = 0) {
            Instrument.api.noteOff.unsafelyUnwrapped(pointer, note, when)
        }

        public func allNotesOff(when: UInt32 = 0) {
            Instrument.api.allNotesOff.unsafelyUnwrapped(pointer, when)
        }

        public func setVolume(left: Float, right: Float) {
            Instrument.api.setVolume.unsafelyUnwrapped(pointer, left, right)
        }

        public var volume: (left: Float, right: Float) {
            var left: Float = 0, right: Float = 0
            Instrument.api.getVolume.unsafelyUnwrapped(pointer, &left, &right)
            return (left, right)
        }

        public var activeVoiceCount: Int {
            Int(Instrument.api.activeVoiceCount.unsafelyUnwrapped(pointer))
        }
    }

    // MARK: - SequenceTrack

    /// A track of notes played by an instrument. Wraps `SequenceTrack`.
    public final class SequenceTrack {
        private static var api: playdate_sound_track { snd.track.pointee }

        let pointer: OpaquePointer
        let isOwned: Bool
        private var retainedInstrument: Instrument?

        init(pointer: OpaquePointer, isOwned: Bool) {
            self.pointer = pointer
            self.isOwned = isOwned
        }

        public convenience init() {
            self.init(pointer: SequenceTrack.api.newTrack.unsafelyUnwrapped().unsafelyUnwrapped,
                      isOwned: true)
        }

        deinit {
            if isOwned {
                SequenceTrack.api.freeTrack.unsafelyUnwrapped(pointer)
            }
        }

        /// The instrument that plays this track's notes.
        public var instrument: Instrument? {
            get {
                if let retainedInstrument { return retainedInstrument }
                guard let instrument = SequenceTrack.api.getInstrument.unsafelyUnwrapped(pointer) else {
                    return nil
                }
                return Instrument(pointer: instrument, isOwned: false)
            }
            set {
                retainedInstrument = newValue
                SequenceTrack.api.setInstrument.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        /// Adds a note starting at `step`, lasting `length` steps.
        public func addNote(step: UInt32, length: UInt32, note: MIDINote, velocity: Float = 1) {
            SequenceTrack.api.addNoteEvent.unsafelyUnwrapped(pointer, step, length, note, velocity)
        }

        public func removeNote(step: UInt32, note: MIDINote) {
            SequenceTrack.api.removeNoteEvent.unsafelyUnwrapped(pointer, step, note)
        }

        public func clearNotes() {
            SequenceTrack.api.clearNotes.unsafelyUnwrapped(pointer)
        }

        /// The track's length in steps, including the tail of the last note.
        public var length: UInt32 {
            SequenceTrack.api.getLength.unsafelyUnwrapped(pointer)
        }

        /// The index of the first note at or after `step`.
        public func indexForStep(_ step: UInt32) -> Int {
            Int(SequenceTrack.api.getIndexForStep.unsafelyUnwrapped(pointer, step))
        }

        /// The note at `index`, or `nil` if the index is out of range.
        public func note(at index: Int) -> (step: UInt32, length: UInt32,
                                            note: MIDINote, velocity: Float)? {
            var step: UInt32 = 0, length: UInt32 = 0
            var note: MIDINote = 0
            var velocity: Float = 0
            guard SequenceTrack.api.getNoteAtIndex.unsafelyUnwrapped(
                pointer, Int32(index), &step, &length, &note, &velocity) != 0 else { return nil }
            return (step, length, note, velocity)
        }

        /// The number of control signals on the track.
        public var controlSignalCount: Int {
            Int(SequenceTrack.api.getControlSignalCount.unsafelyUnwrapped(pointer))
        }

        /// The control signal at `index`. Owned by the track.
        public func controlSignal(at index: Int) -> ControlSignal? {
            guard let signal = SequenceTrack.api.getControlSignal.unsafelyUnwrapped(
                pointer, Int32(index)) else { return nil }
            return ControlSignal(pointer: signal, isOwned: false)
        }

        /// The control signal for MIDI controller `controller`, optionally
        /// creating it. Owned by the track.
        public func signalForController(_ controller: Int, create: Bool = false) -> ControlSignal? {
            guard let signal = SequenceTrack.api.getSignalForController.unsafelyUnwrapped(
                pointer, Int32(controller), create ? 1 : 0) else { return nil }
            return ControlSignal(pointer: signal, isOwned: false)
        }

        public func clearControlEvents() {
            SequenceTrack.api.clearControlEvents.unsafelyUnwrapped(pointer)
        }

        /// The maximum number of simultaneous notes in the track.
        public var polyphony: Int {
            Int(SequenceTrack.api.getPolyphony.unsafelyUnwrapped(pointer))
        }

        public var activeVoiceCount: Int {
            Int(SequenceTrack.api.activeVoiceCount.unsafelyUnwrapped(pointer))
        }

        public func setMuted(_ muted: Bool) {
            SequenceTrack.api.setMuted.unsafelyUnwrapped(pointer, muted ? 1 : 0)
        }
    }

    // MARK: - Sequence

    /// A collection of tracks with tempo and loop control, playable from a
    /// MIDI file. Wraps `SoundSequence`.
    public final class Sequence {
        private static var api: playdate_sound_sequence { snd.sequence.pointee }

        let pointer: OpaquePointer
        private var retainedTracks: [SequenceTrack] = []
        var finishCallback: ((Sequence) -> Void)?

        public init() {
            pointer = Sequence.api.newSequence.unsafelyUnwrapped().unsafelyUnwrapped
        }

        /// Creates a sequence and loads the MIDI file at `path`.
        public convenience init(midiFilePath: String) throws(Playdate.Error) {
            self.init()
            try loadMIDIFile(path: midiFilePath)
        }

        deinit {
            Sequence.api.freeSequence.unsafelyUnwrapped(pointer)
        }

        public func loadMIDIFile(path: String) throws(Playdate.Error) {
            let loaded = path.withPlaydateCString {
                Sequence.api.loadMIDIFile.unsafelyUnwrapped(pointer, $0) != 0
            }
            if !loaded {
                throw Playdate.Error(message: "unable to load MIDI file: \(path)")
            }
        }

        /// Starts playback. `completion` is called when the sequence finishes.
        public func play(completion: ((Sequence) -> Void)? = nil) {
            finishCallback = completion
            if completion != nil {
                Sequence.api.play.unsafelyUnwrapped(pointer, { _, userdata in
                    guard let userdata else { return }
                    let sequence = Unmanaged<Sequence>.fromOpaque(userdata).takeUnretainedValue()
                    sequence.finishCallback?(sequence)
                }, Unmanaged.passUnretained(self).toOpaque())
            } else {
                Sequence.api.play.unsafelyUnwrapped(pointer, nil, nil)
            }
        }

        public func stop() {
            Sequence.api.stop.unsafelyUnwrapped(pointer)
        }

        public var isPlaying: Bool {
            Sequence.api.isPlaying.unsafelyUnwrapped(pointer) != 0
        }

        /// The playback position, in samples.
        public var time: UInt32 {
            get { Sequence.api.getTime.unsafelyUnwrapped(pointer) }
            set { Sequence.api.setTime.unsafelyUnwrapped(pointer, newValue) }
        }

        /// The tempo, in steps per second.
        public var tempo: Float {
            get { Sequence.api.getTempo.unsafelyUnwrapped(pointer) }
            set { Sequence.api.setTempo.unsafelyUnwrapped(pointer, newValue) }
        }

        /// The sequence's length in steps, including the tail of the last note.
        public var length: UInt32 {
            Sequence.api.getLength.unsafelyUnwrapped(pointer)
        }

        /// Loops the range `loopStart..<loopEnd` (steps) `loops` times while
        /// playing; 0 loops endlessly.
        public func setLoops(start: Int, end: Int, count: Int = 0) {
            Sequence.api.setLoops.unsafelyUnwrapped(pointer, Int32(start), Int32(end), Int32(count))
        }

        /// The current step, and the time offset (in samples) into that step.
        public var currentStep: (step: Int, timeOffset: Int) {
            var timeOffset: Int32 = 0
            let step = Sequence.api.getCurrentStep.unsafelyUnwrapped(pointer, &timeOffset)
            return (Int(step), Int(timeOffset))
        }

        /// Moves playback to the given step. If `playNotes` is `true`, notes
        /// at the position (that started before it) are played.
        public func setCurrentStep(_ step: Int, timeOffset: Int = 0, playNotes: Bool = false) {
            Sequence.api.setCurrentStep.unsafelyUnwrapped(pointer, Int32(step),
                                                          Int32(timeOffset), playNotes ? 1 : 0)
        }

        // MARK: Tracks

        public var trackCount: Int {
            Int(Sequence.api.getTrackCount.unsafelyUnwrapped(pointer))
        }

        /// Adds a new track to the sequence. The track is owned by the
        /// sequence.
        @discardableResult
        public func addTrack() -> SequenceTrack {
            let track = SequenceTrack(
                pointer: Sequence.api.addTrack.unsafelyUnwrapped(pointer).unsafelyUnwrapped,
                isOwned: false)
            retainedTracks.append(track)
            return track
        }

        /// The track at `index`. Owned by the sequence.
        public func track(at index: Int) -> SequenceTrack? {
            guard let track = Sequence.api.getTrackAtIndex.unsafelyUnwrapped(
                pointer, UInt32(index)) else { return nil }
            return SequenceTrack(pointer: track, isOwned: false)
        }

        /// Installs `track` at `index`.
        public func setTrack(_ track: SequenceTrack, at index: Int) {
            if !retainedTracks.contains(where: { $0 === track }) {
                retainedTracks.append(track)
            }
            Sequence.api.setTrackAtIndex.unsafelyUnwrapped(pointer, track.pointer, UInt32(index))
        }

        /// Releases every playing note in the sequence.
        public func allNotesOff() {
            Sequence.api.allNotesOff.unsafelyUnwrapped(pointer)
        }
    }
}
