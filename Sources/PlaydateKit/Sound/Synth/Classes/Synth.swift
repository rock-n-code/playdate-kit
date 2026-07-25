internal import CPlaydate

extension Sound {
    /// A synthesizer voice. Wraps `PDSynth`.
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

        /// Copies the synth (and its generator, if any).
        public func copy() -> Synth {
            Synth(pointer: Synth.api.pointee.copy.unsafelyUnwrapped(pointer).unsafelyUnwrapped,
                  isOwned: true)
        }

        // MARK: Sound generation

        public func setWaveform(_ waveform: Waveform) {
            Synth.api.pointee.setWaveform.unsafelyUnwrapped(pointer, waveform.cValue)
        }

        /// Plays a sample instead of a waveform. A nonzero sustain range
        /// loops that part of the sample while the note is held.
        public func setSample(_ sample: AudioSample, sustainStart: UInt32 = 0, sustainEnd: UInt32 = 0) {
            retainedSample = sample
            Synth.api.pointee.setSample.unsafelyUnwrapped(pointer, sample.pointer, sustainStart, sustainEnd)
        }

        /// Uses a wavetable for the synth. `log2size` is the base-2 log of
        /// each waveform's size (e.g. 8 for 256 samples).
        public func setWavetable(_ sample: AudioSample, log2size: Int,
                                 columns: Int, rows: Int) throws(PlaydateError) {
            retainedSample = sample
            guard Synth.api.pointee.setWavetable.unsafelyUnwrapped(
                pointer, sample.pointer, Int32(log2size), Int32(columns), Int32(rows)) != 0 else {
                throw PlaydateError(message: "invalid wavetable dimensions")
            }
        }

        /// Provides audio via custom Swift callbacks.
        public func setGenerator(stereo: Bool, _ generator: Generator) {
            let box = Unmanaged.passRetained(GeneratorBox(generator, stereo: stereo))
            Synth.api.pointee.setGenerator.unsafelyUnwrapped(
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

        /// The envelope's attack time, in seconds.
        public func setAttackTime(_ attack: Float) {
            Synth.api.pointee.setAttackTime.unsafelyUnwrapped(pointer, attack)
        }

        /// The envelope's decay time, in seconds.
        public func setDecayTime(_ decay: Float) {
            Synth.api.pointee.setDecayTime.unsafelyUnwrapped(pointer, decay)
        }

        /// The envelope's sustain level, 0...1.
        public func setSustainLevel(_ sustain: Float) {
            Synth.api.pointee.setSustainLevel.unsafelyUnwrapped(pointer, sustain)
        }

        /// The envelope's release time, in seconds.
        public func setReleaseTime(_ release: Float) {
            Synth.api.pointee.setReleaseTime.unsafelyUnwrapped(pointer, release)
        }

        /// The synth's amplitude envelope. Owned by the synth.
        public var envelope: Envelope? {
            guard let envelope = Synth.api.pointee.getEnvelope.unsafelyUnwrapped(pointer) else { return nil }
            return Envelope(pointer: envelope, isOwned: false)
        }

        /// Clears the synth's envelope so it plays at constant volume.
        public func clearEnvelope() {
            Synth.api.pointee.clearEnvelope.unsafelyUnwrapped(pointer)
        }

        // MARK: Modulation

        /// Transposes played notes by `halfSteps` (fractional values allowed).
        public func setTranspose(_ halfSteps: Float) {
            Synth.api.pointee.setTranspose.unsafelyUnwrapped(pointer, halfSteps)
        }

        /// Modulates the synth's frequency.
        public var frequencyModulator: SignalValue? {
            get { SignalValue.wrap(Synth.api.pointee.getFrequencyModulator.unsafelyUnwrapped(pointer)) }
            set {
                retain(newValue)
                Synth.api.pointee.setFrequencyModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        /// Modulates the synth's amplitude.
        public var amplitudeModulator: SignalValue? {
            get { SignalValue.wrap(Synth.api.pointee.getAmplitudeModulator.unsafelyUnwrapped(pointer)) }
            set {
                retain(newValue)
                Synth.api.pointee.setAmplitudeModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        /// The number of parameters the synth's generator supports.
        public var parameterCount: Int {
            Int(Synth.api.pointee.getParameterCount.unsafelyUnwrapped(pointer))
        }

        /// Sets a generator parameter. Returns `false` if the parameter is
        /// invalid.
        @discardableResult
        public func setParameter(_ parameter: Int, value: Float) -> Bool {
            Synth.api.pointee.setParameter.unsafelyUnwrapped(pointer, Int32(parameter), value) != 0
        }

        /// Modulates a generator parameter.
        public func setParameterModulator(_ parameter: Int, _ modulator: SignalValue?) {
            retain(modulator)
            Synth.api.pointee.setParameterModulator.unsafelyUnwrapped(pointer, Int32(parameter),
                                                              modulator?.pointer)
        }

        /// The modulator installed on a generator parameter, if any.
        public func parameterModulator(_ parameter: Int) -> SignalValue? {
            SignalValue.wrap(Synth.api.pointee.getParameterModulator.unsafelyUnwrapped(pointer, Int32(parameter)))
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
            Synth.api.pointee.playNote.unsafelyUnwrapped(pointer, frequency, velocity, length ?? -1, when)
        }

        /// Plays a MIDI note, where 60 is middle C.
        public func playMIDINote(_ note: MIDINote, velocity: Float = 1,
                                 length: Float? = nil, when: UInt32 = 0) {
            Synth.api.pointee.playMIDINote.unsafelyUnwrapped(pointer, note, velocity, length ?? -1, when)
        }

        /// Releases the playing note at time `when`, or immediately if 0.
        public func noteOff(when: UInt32 = 0) {
            Synth.api.pointee.noteOff.unsafelyUnwrapped(pointer, when)
        }

        /// Stops the synth immediately, without playing the release phase.
        public func stop() {
            Synth.api.pointee.stop.unsafelyUnwrapped(pointer)
        }
    }
}
