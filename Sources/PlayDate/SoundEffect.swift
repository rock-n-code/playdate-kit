//
//  SoundEffect.swift
//  SoundEffect wrappers: filters, bitcrusher, ring modulator, delay line,
//  and overdrive.
//

internal import CPlaydate

private var effectAPI: playdate_sound_effect { snd.effect.pointee }

extension Playdate.Sound {
    /// An effect that processes a channel's audio: the base class of the
    /// built-in effects. Wraps `SoundEffect`.
    public class Effect {
        /// Processes up to `AUDIO_FRAMES_PER_CYCLE` sample frames in signed
        /// Q8.24 format. `bufferActive` is `false` when the input buffer is
        /// silent. Returns `true` if the effect produced output.
        public typealias Processor = (_ left: UnsafeMutableBufferPointer<Int32>,
                                      _ right: UnsafeMutableBufferPointer<Int32>?,
                                      _ bufferActive: Bool) -> Bool

        let pointer: OpaquePointer
        let isOwned: Bool
        private var retainedMixModulator: SignalValue?
        private var processorBox: Unmanaged<ProcessorBox>?

        final class ProcessorBox {
            let processor: Processor
            init(_ processor: @escaping Processor) { self.processor = processor }
        }

        init(pointer: OpaquePointer, isOwned: Bool) {
            self.pointer = pointer
            self.isOwned = isOwned
        }

        /// Creates an effect that processes audio with a Swift callback.
        public init(processor: @escaping Processor) {
            let box = Unmanaged.passRetained(ProcessorBox(processor))
            processorBox = box
            pointer = effectAPI.newEffect.unsafelyUnwrapped({ effect, left, right, nsamples, bufactive in
                guard let effect, let left,
                      let userdata = effectAPI.getUserdata.unsafelyUnwrapped(effect) else { return 0 }
                let box = Unmanaged<ProcessorBox>.fromOpaque(userdata).takeUnretainedValue()
                let leftBuffer = UnsafeMutableBufferPointer(start: left, count: Int(nsamples))
                let rightBuffer = right.map { UnsafeMutableBufferPointer(start: $0, count: Int(nsamples)) }
                return box.processor(leftBuffer, rightBuffer, bufactive != 0) ? 1 : 0
            }, box.toOpaque()).unsafelyUnwrapped
            isOwned = true
        }

        deinit {
            if isOwned {
                effectAPI.freeEffect.unsafelyUnwrapped(pointer)
            }
            processorBox?.release()
        }

        /// The wet/dry mix: 1 is fully processed, 0 fully dry.
        public func setMix(_ level: Float) {
            effectAPI.setMix.unsafelyUnwrapped(pointer, level)
        }

        public var mixModulator: SignalValue? {
            get { SignalValue.wrap(effectAPI.getMixModulator.unsafelyUnwrapped(pointer)) }
            set {
                retainedMixModulator = newValue
                effectAPI.setMixModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }
    }

    // MARK: - Two-pole filter

    /// A two-pole IIR filter. Wraps `TwoPoleFilter`.
    public final class TwoPoleFilter: Effect {
        private static var api: playdate_sound_effect_twopolefilter { effectAPI.twopolefilter.pointee }

        public enum Kind: UInt32, Sendable {
            case lowPass = 0
            case highPass = 1
            case bandPass = 2
            case notch = 3
            case peq = 4
            case lowShelf = 5
            case highShelf = 6

            var cValue: TwoPoleFilterType { TwoPoleFilterType(rawValue) }
        }

        private var retainedFrequencyModulator: SignalValue?
        private var retainedResonanceModulator: SignalValue?

        public init(kind: Kind = .lowPass) {
            super.init(pointer: TwoPoleFilter.api.newFilter.unsafelyUnwrapped().unsafelyUnwrapped,
                       isOwned: true)
            setKind(kind)
        }

        deinit {
            if isOwned {
                TwoPoleFilter.api.freeFilter.unsafelyUnwrapped(pointer)
            }
        }

        public func setKind(_ kind: Kind) {
            TwoPoleFilter.api.setType.unsafelyUnwrapped(pointer, kind.cValue)
        }

        /// The center/corner frequency, in Hz.
        public func setFrequency(_ frequency: Float) {
            TwoPoleFilter.api.setFrequency.unsafelyUnwrapped(pointer, frequency)
        }

        public var frequencyModulator: SignalValue? {
            get { SignalValue.wrap(TwoPoleFilter.api.getFrequencyModulator.unsafelyUnwrapped(pointer)) }
            set {
                retainedFrequencyModulator = newValue
                TwoPoleFilter.api.setFrequencyModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        /// The gain, used by PEQ and shelf filters.
        public func setGain(_ gain: Float) {
            TwoPoleFilter.api.setGain.unsafelyUnwrapped(pointer, gain)
        }

        public func setResonance(_ resonance: Float) {
            TwoPoleFilter.api.setResonance.unsafelyUnwrapped(pointer, resonance)
        }

        public var resonanceModulator: SignalValue? {
            get { SignalValue.wrap(TwoPoleFilter.api.getResonanceModulator.unsafelyUnwrapped(pointer)) }
            set {
                retainedResonanceModulator = newValue
                TwoPoleFilter.api.setResonanceModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }
    }

    // MARK: - One-pole filter

    /// A one-pole low/high-pass filter. Wraps `OnePoleFilter`.
    public final class OnePoleFilter: Effect {
        private static var api: playdate_sound_effect_onepolefilter { effectAPI.onepolefilter.pointee }

        private var retainedParameterModulator: SignalValue?

        public init() {
            super.init(pointer: OnePoleFilter.api.newFilter.unsafelyUnwrapped().unsafelyUnwrapped,
                       isOwned: true)
        }

        deinit {
            if isOwned {
                OnePoleFilter.api.freeFilter.unsafelyUnwrapped(pointer)
            }
        }

        /// The filter's cutoff: -1 to 1, where values above 0 are low-pass
        /// and values below 0 high-pass.
        public func setParameter(_ parameter: Float) {
            OnePoleFilter.api.setParameter.unsafelyUnwrapped(pointer, parameter)
        }

        public var parameterModulator: SignalValue? {
            get { SignalValue.wrap(OnePoleFilter.api.getParameterModulator.unsafelyUnwrapped(pointer)) }
            set {
                retainedParameterModulator = newValue
                OnePoleFilter.api.setParameterModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }
    }

    // MARK: - Bit crusher

    /// A bit-crushing and downsampling effect. Wraps `BitCrusher`.
    public final class BitCrusher: Effect {
        private static var api: playdate_sound_effect_bitcrusher { effectAPI.bitcrusher.pointee }

        private var retainedModulators: [SignalValue] = []

        public init() {
            super.init(pointer: BitCrusher.api.newBitCrusher.unsafelyUnwrapped().unsafelyUnwrapped,
                       isOwned: true)
        }

        deinit {
            if isOwned {
                BitCrusher.api.freeBitCrusher.unsafelyUnwrapped(pointer)
            }
        }

        /// When `true`, `setDepth` values map exponentially to bit depth.
        public func setExponential(_ flag: Bool) {
            BitCrusher.api.setExponential.unsafelyUnwrapped(pointer, flag)
        }

        /// The amount of crushing, 0 (none) to 1 (quantized to 1 bit).
        public func setDepth(_ depth: Float) {
            BitCrusher.api.setDepth.unsafelyUnwrapped(pointer, depth)
        }

        public var depthModulator: SignalValue? {
            get { SignalValue.wrap(BitCrusher.api.getDepthModulator.unsafelyUnwrapped(pointer)) }
            set {
                retain(newValue)
                BitCrusher.api.setDepthModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        /// The amount of downsampling, 0 (none) to 1 (every sample repeated).
        public func setDownsampling(_ downsampling: Float) {
            BitCrusher.api.setDownsampling.unsafelyUnwrapped(pointer, downsampling)
        }

        public var downsamplingModulator: SignalValue? {
            get { SignalValue.wrap(BitCrusher.api.getDownsamplingModulator.unsafelyUnwrapped(pointer)) }
            set {
                retain(newValue)
                BitCrusher.api.setDownsamplingModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        private func retain(_ modulator: SignalValue?) {
            if let modulator { retainedModulators.append(modulator) }
        }
    }

    // MARK: - Ring modulator

    /// A ring modulator effect. Wraps `RingModulator`.
    public final class RingModulator: Effect {
        private static var api: playdate_sound_effect_ringmodulator { effectAPI.ringmodulator.pointee }

        private var retainedFrequencyModulator: SignalValue?

        public init() {
            super.init(pointer: RingModulator.api.newRingmod.unsafelyUnwrapped().unsafelyUnwrapped,
                       isOwned: true)
        }

        deinit {
            if isOwned {
                RingModulator.api.freeRingmod.unsafelyUnwrapped(pointer)
            }
        }

        /// The modulation frequency, in Hz.
        public func setFrequency(_ frequency: Float) {
            RingModulator.api.setFrequency.unsafelyUnwrapped(pointer, frequency)
        }

        public var frequencyModulator: SignalValue? {
            get { SignalValue.wrap(RingModulator.api.getFrequencyModulator.unsafelyUnwrapped(pointer)) }
            set {
                retainedFrequencyModulator = newValue
                RingModulator.api.setFrequencyModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }
    }

    // MARK: - Delay line

    /// A tap into a delay line; produces audio and can be added to a channel
    /// as a source. Wraps `DelayLineTap`.
    public final class DelayLineTap: Source {
        private static var api: playdate_sound_effect_delayline { effectAPI.delayline.pointee }

        /// The delay line is retained so the tap stays valid.
        private let delayLine: DelayLine
        private var retainedDelayModulator: SignalValue?

        init(pointer: OpaquePointer, delayLine: DelayLine) {
            self.delayLine = delayLine
            super.init(pointer: pointer, isOwned: true)
        }

        deinit {
            DelayLineTap.api.freeTap.unsafelyUnwrapped(pointer)
        }

        /// The tap's position in the delay line, in frames.
        public func setDelay(frames: Int) {
            DelayLineTap.api.setTapDelay.unsafelyUnwrapped(pointer, Int32(frames))
        }

        public var delayModulator: SignalValue? {
            get { SignalValue.wrap(DelayLineTap.api.getTapDelayModulator.unsafelyUnwrapped(pointer)) }
            set {
                retainedDelayModulator = newValue
                DelayLineTap.api.setTapDelayModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        /// For stereo delay lines: swaps the left and right channels.
        public func setChannelsFlipped(_ flipped: Bool) {
            DelayLineTap.api.setTapChannelsFlipped.unsafelyUnwrapped(pointer, flipped ? 1 : 0)
        }
    }

    /// A delay line effect. Wraps `DelayLine`.
    public final class DelayLine: Effect {
        private static var api: playdate_sound_effect_delayline { effectAPI.delayline.pointee }

        /// Creates a delay line holding `length` frames.
        public init(length: Int, stereo: Bool = false) {
            super.init(pointer: DelayLine.api.newDelayLine.unsafelyUnwrapped(
                Int32(length), stereo ? 1 : 0).unsafelyUnwrapped, isOwned: true)
        }

        deinit {
            if isOwned {
                DelayLine.api.freeDelayLine.unsafelyUnwrapped(pointer)
            }
        }

        /// Changes the delay length. Cannot be larger than the line's
        /// original length.
        public func setLength(frames: Int) {
            DelayLine.api.setLength.unsafelyUnwrapped(pointer, Int32(frames))
        }

        /// The feedback level, 0...1.
        public func setFeedback(_ feedback: Float) {
            DelayLine.api.setFeedback.unsafelyUnwrapped(pointer, feedback)
        }

        /// Adds a tap `delay` frames behind the write head. The tap can be
        /// added to a channel as a sound source.
        public func addTap(delay: Int) -> DelayLineTap? {
            guard let tap = DelayLine.api.addTap.unsafelyUnwrapped(pointer, Int32(delay)) else {
                return nil
            }
            return DelayLineTap(pointer: tap, delayLine: self)
        }
    }

    // MARK: - Overdrive

    /// An overdrive/distortion effect. Wraps `Overdrive`.
    public final class Overdrive: Effect {
        private static var api: playdate_sound_effect_overdrive { effectAPI.overdrive.pointee }

        private var retainedModulators: [SignalValue] = []

        public init() {
            super.init(pointer: Overdrive.api.newOverdrive.unsafelyUnwrapped().unsafelyUnwrapped,
                       isOwned: true)
        }

        deinit {
            if isOwned {
                Overdrive.api.freeOverdrive.unsafelyUnwrapped(pointer)
            }
        }

        /// The input gain applied before clipping.
        public func setGain(_ gain: Float) {
            Overdrive.api.setGain.unsafelyUnwrapped(pointer, gain)
        }

        /// The level where the amplified input clips.
        public func setLimit(_ limit: Float) {
            Overdrive.api.setLimit.unsafelyUnwrapped(pointer, limit)
        }

        public var limitModulator: SignalValue? {
            get { SignalValue.wrap(Overdrive.api.getLimitModulator.unsafelyUnwrapped(pointer)) }
            set {
                retain(newValue)
                Overdrive.api.setLimitModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        /// A DC offset applied to the input, making the clipping asymmetric.
        public func setOffset(_ offset: Float) {
            Overdrive.api.setOffset.unsafelyUnwrapped(pointer, offset)
        }

        public var offsetModulator: SignalValue? {
            get { SignalValue.wrap(Overdrive.api.getOffsetModulator.unsafelyUnwrapped(pointer)) }
            set {
                retain(newValue)
                Overdrive.api.setOffsetModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        private func retain(_ modulator: SignalValue?) {
            if let modulator { retainedModulators.append(modulator) }
        }
    }
}
