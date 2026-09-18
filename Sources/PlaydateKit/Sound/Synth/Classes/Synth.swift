internal import CPlaydate

extension Sound {
    /// A synthesizer voice. Wraps `PDSynth`. Keeps samples and generators set on it alive.
    public final class Synth: Source {
        private static var api: UnsafePointer<playdate_sound_synth> { Playdate.synthAPI.unsafelyUnwrapped }

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
            self.init(pointer: Synth.api.pointee.newSynth.unsafelyUnwrapped().unsafelyUnwrapped,
                      isOwned: true)
        }

        public convenience init(waveform: Waveform) {
            self.init()
            setWaveform(waveform)
        }

        deinit {
            if isOwned {
                Synth.api.pointee.freeSynth.unsafelyUnwrapped(pointer)
            }
        }

        /// An independently owned copy, including any generator.
        public func copy() -> Synth {
            Synth(pointer: Synth.api.pointee.copy.unsafelyUnwrapped(pointer).unsafelyUnwrapped,
                  isOwned: true)
        }

        // MARK: Sound generation

        public func setWaveform(_ waveform: Waveform) {
            Synth.api.pointee.setWaveform.unsafelyUnwrapped(pointer, waveform.cValue)
        }

        /// Plays `sample` (uncompressed PCM, not ADPCM). Frames `sustainStart..<sustainEnd`
        /// loop while held; `sustainEnd` 0 with nonzero `sustainStart` means the sample's end.
        public func setSample(_ sample: AudioSample, sustainStart: UInt32 = 0, sustainEnd: UInt32 = 0) {
            retainedSample = sample
            Synth.api.pointee.setSample.unsafelyUnwrapped(pointer, sample.pointer, sustainStart, sustainEnd)
        }

        /// Plays `sample` (16-bit mono, uncompressed) as `columns` × `rows` cells of
        /// 2^`log2size` samples; parameters 1–4 select the position.
        public func setWavetable(_ sample: AudioSample, log2size: Int,
                                 columns: Int, rows: Int) throws(PlaydateError) {
            retainedSample = sample
            guard Synth.api.pointee.setWavetable.unsafelyUnwrapped(
                pointer, sample.pointer, Int32(log2size), Int32(columns), Int32(rows)) != 0 else {
                throw PlaydateError(message: "invalid wavetable dimensions")
            }
        }

        /// `copy()` shares `generator`.
        public func setGenerator(stereo: Bool, _ generator: Generator) {
            let box = Unmanaged.passRetained(GeneratorBox(generator, stereo: stereo))
            Synth.api.pointee.setGenerator.unsafelyUnwrapped(
                pointer, stereo ? 1 : 0,
                { userdata, left, right, nsamples, rate, drate in
                    guard let userdata, let left else { return 0 }
                    let box = Unmanaged<GeneratorBox>.fromOpaque(userdata).takeUnretainedValue()
                    var leftSpan = UnsafeMutableBufferPointer(start: left, count: Int(nsamples)).mutableSpan
                    var rightSpan = UnsafeMutableBufferPointer(start: right, count: right == nil ? 0 : Int(nsamples)).mutableSpan
                    return Int32(box.generator.render(&leftSpan, &rightSpan, rate, drate))
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

        /// In seconds.
        public func setAttackTime(_ attack: Float) {
            Synth.api.pointee.setAttackTime.unsafelyUnwrapped(pointer, attack)
        }

        /// In seconds.
        public func setDecayTime(_ decay: Float) {
            Synth.api.pointee.setDecayTime.unsafelyUnwrapped(pointer, decay)
        }

        /// 0...1.
        public func setSustainLevel(_ sustain: Float) {
            Synth.api.pointee.setSustainLevel.unsafelyUnwrapped(pointer, sustain)
        }

        /// In seconds.
        public func setReleaseTime(_ release: Float) {
            Synth.api.pointee.setReleaseTime.unsafelyUnwrapped(pointer, release)
        }

        /// The amplitude envelope; owned by the synth, valid only while it is alive.
        public var envelope: Envelope? {
            guard let envelope = Synth.api.pointee.getEnvelope.unsafelyUnwrapped(pointer) else { return nil }
            return Envelope(pointer: envelope, isOwned: false)
        }

        public func clearEnvelope() {
            Synth.api.pointee.clearEnvelope.unsafelyUnwrapped(pointer)
        }

        // MARK: Pitch, modulation, and parameters

        /// Fractional half-steps allowed.
        public func setTranspose(_ halfSteps: Float) {
            Synth.api.pointee.setTranspose.unsafelyUnwrapped(pointer, halfSteps)
        }

        /// 1 is an octave up, -1 an octave down.
        public var frequencyModulator: SignalValue? {
            get { SignalValue.wrap(Synth.api.pointee.getFrequencyModulator.unsafelyUnwrapped(pointer)) }
            set {
                retain(newValue)
                Synth.api.pointee.setFrequencyModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        public var amplitudeModulator: SignalValue? {
            get { SignalValue.wrap(Synth.api.pointee.getAmplitudeModulator.unsafelyUnwrapped(pointer)) }
            set {
                retain(newValue)
                Synth.api.pointee.setAmplitudeModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        /// The number of parameters the generator supports.
        public var parameterCount: Int {
            Int(Synth.api.pointee.getParameterCount.unsafelyUnwrapped(pointer))
        }

        /// `parameter` is 1-based. Returns `false` if it is invalid.
        @discardableResult
        public func setParameter(_ parameter: Int, value: Float) -> Bool {
            Synth.api.pointee.setParameter.unsafelyUnwrapped(pointer, Int32(parameter), value) != 0
        }

        /// `parameter` is 1-based.
        public func setParameterModulator(_ parameter: Int, _ modulator: SignalValue?) {
            retain(modulator)
            Synth.api.pointee.setParameterModulator.unsafelyUnwrapped(pointer, Int32(parameter),
                                                              modulator?.pointer)
        }

        /// `parameter` is 1-based.
        public func parameterModulator(_ parameter: Int) -> SignalValue? {
            SignalValue.wrap(Synth.api.pointee.getParameterModulator.unsafelyUnwrapped(pointer, Int32(parameter)))
        }

        private func retain(_ modulator: SignalValue?) {
            if let modulator, !retainedModulators.contains(where: { $0 === modulator }) {
                retainedModulators.append(modulator)
            }
        }

        // MARK: Playing

        /// `frequency` in Hz; `length` in seconds, `nil` until `noteOff(when:)`;
        /// `when` is an audio-clock time, 0 for now.
        public func playNote(frequency: Float, velocity: Float = 1,
                             length: Float? = nil, when: UInt32 = 0) {
            Synth.api.pointee.playNote.unsafelyUnwrapped(pointer, frequency, velocity, length ?? -1, when)
        }

        /// 60 is C4; fractional notes allowed. Other arguments as in `playNote`.
        public func playMIDINote(_ note: MIDINote, velocity: Float = 1,
                                 length: Float? = nil, when: UInt32 = 0) {
            Synth.api.pointee.playMIDINote.unsafelyUnwrapped(pointer, note, velocity, length ?? -1, when)
        }

        /// Releases the note at audio-clock time `when`, or now if 0.
        public func noteOff(when: UInt32 = 0) {
            Synth.api.pointee.noteOff.unsafelyUnwrapped(pointer, when)
        }

        /// Stops immediately, skipping the release phase.
        public func stop() {
            Synth.api.pointee.stop.unsafelyUnwrapped(pointer)
        }
    }
}
