//
//  SoundEffect.swift
//  SoundEffect wrappers: filters, bitcrusher, ring modulator, delay line,
//  and overdrive.
//

internal import CPlaydate

private var effectAPI: UnsafePointer<playdate_sound_effect> { snd.pointee.effect.unsafelyUnwrapped }

extension Sound {
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
            pointer = effectAPI.pointee.newEffect.unsafelyUnwrapped({ effect, left, right, nsamples, bufactive in
                guard let effect, let left,
                      let userdata = effectAPI.pointee.getUserdata.unsafelyUnwrapped(effect) else { return 0 }
                let box = Unmanaged<ProcessorBox>.fromOpaque(userdata).takeUnretainedValue()
                let leftBuffer = UnsafeMutableBufferPointer(start: left, count: Int(nsamples))
                let rightBuffer = right.map { UnsafeMutableBufferPointer(start: $0, count: Int(nsamples)) }
                return box.processor(leftBuffer, rightBuffer, bufactive != 0) ? 1 : 0
            }, box.toOpaque()).unsafelyUnwrapped
            isOwned = true
        }

        deinit {
            if isOwned {
                effectAPI.pointee.freeEffect.unsafelyUnwrapped(pointer)
            }
            processorBox?.release()
        }

        /// The wet/dry mix: 1 is fully processed, 0 fully dry.
        public func setMix(_ level: Float) {
            effectAPI.pointee.setMix.unsafelyUnwrapped(pointer, level)
        }

        public var mixModulator: SignalValue? {
            get { SignalValue.wrap(effectAPI.pointee.getMixModulator.unsafelyUnwrapped(pointer)) }
            set {
                retainedMixModulator = newValue
                effectAPI.pointee.setMixModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }
    }

    // MARK: - Two-pole filter

    /// A two-pole IIR filter. Wraps `TwoPoleFilter`.
    public final class TwoPoleFilter: Effect {
        private static var api: UnsafePointer<playdate_sound_effect_twopolefilter> { effectAPI.pointee.twopolefilter.unsafelyUnwrapped }

        public enum Kind: UInt32, Sendable {
            case lowPass = 0
            case highPass = 1
            case bandPass = 2
            case notch = 3
            case peq = 4
            case lowShelf = 5
            case highShelf = 6

            var cValue: TwoPoleFilterType { TwoPoleFilterType(TwoPoleFilterType.RawValue(rawValue)) }
        }

        private var retainedFrequencyModulator: SignalValue?
        private var retainedResonanceModulator: SignalValue?

        public init(kind: Kind = .lowPass) {
            super.init(pointer: TwoPoleFilter.api.pointee.newFilter.unsafelyUnwrapped().unsafelyUnwrapped,
                       isOwned: true)
            setKind(kind)
        }

        deinit {
            if isOwned {
                TwoPoleFilter.api.pointee.freeFilter.unsafelyUnwrapped(pointer)
            }
        }

        public func setKind(_ kind: Kind) {
            TwoPoleFilter.api.pointee.setType.unsafelyUnwrapped(pointer, kind.cValue)
        }

        /// The center/corner frequency, in Hz.
        public func setFrequency(_ frequency: Float) {
            TwoPoleFilter.api.pointee.setFrequency.unsafelyUnwrapped(pointer, frequency)
        }

        public var frequencyModulator: SignalValue? {
            get { SignalValue.wrap(TwoPoleFilter.api.pointee.getFrequencyModulator.unsafelyUnwrapped(pointer)) }
            set {
                retainedFrequencyModulator = newValue
                TwoPoleFilter.api.pointee.setFrequencyModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        /// The gain, used by PEQ and shelf filters.
        public func setGain(_ gain: Float) {
            TwoPoleFilter.api.pointee.setGain.unsafelyUnwrapped(pointer, gain)
        }

        public func setResonance(_ resonance: Float) {
            TwoPoleFilter.api.pointee.setResonance.unsafelyUnwrapped(pointer, resonance)
        }

        public var resonanceModulator: SignalValue? {
            get { SignalValue.wrap(TwoPoleFilter.api.pointee.getResonanceModulator.unsafelyUnwrapped(pointer)) }
            set {
                retainedResonanceModulator = newValue
                TwoPoleFilter.api.pointee.setResonanceModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }
    }

    // MARK: - One-pole filter

    /// A one-pole low/high-pass filter. Wraps `OnePoleFilter`.
    public final class OnePoleFilter: Effect {
        private static var api: UnsafePointer<playdate_sound_effect_onepolefilter> { effectAPI.pointee.onepolefilter.unsafelyUnwrapped }

        private var retainedParameterModulator: SignalValue?

        public init() {
            super.init(pointer: OnePoleFilter.api.pointee.newFilter.unsafelyUnwrapped().unsafelyUnwrapped,
                       isOwned: true)
        }

        deinit {
            if isOwned {
                OnePoleFilter.api.pointee.freeFilter.unsafelyUnwrapped(pointer)
            }
        }

        /// The filter's cutoff: -1 to 1, where values above 0 are low-pass
        /// and values below 0 high-pass.
        public func setParameter(_ parameter: Float) {
            OnePoleFilter.api.pointee.setParameter.unsafelyUnwrapped(pointer, parameter)
        }

        public var parameterModulator: SignalValue? {
            get { SignalValue.wrap(OnePoleFilter.api.pointee.getParameterModulator.unsafelyUnwrapped(pointer)) }
            set {
                retainedParameterModulator = newValue
                OnePoleFilter.api.pointee.setParameterModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }
    }

    // MARK: - Bit crusher

    /// A bit-crushing and downsampling effect. Wraps `BitCrusher`.
    public final class BitCrusher: Effect {
        private static var api: UnsafePointer<playdate_sound_effect_bitcrusher> { effectAPI.pointee.bitcrusher.unsafelyUnwrapped }

        private var retainedModulators: [SignalValue] = []

        public init() {
            super.init(pointer: BitCrusher.api.pointee.newBitCrusher.unsafelyUnwrapped().unsafelyUnwrapped,
                       isOwned: true)
        }

        deinit {
            if isOwned {
                BitCrusher.api.pointee.freeBitCrusher.unsafelyUnwrapped(pointer)
            }
        }

        /// When `true`, `setDepth` values map exponentially to bit depth.
        public func setExponential(_ flag: Bool) {
            BitCrusher.api.pointee.setExponential.unsafelyUnwrapped(pointer, flag)
        }

        /// The amount of crushing, 0 (none) to 1 (quantized to 1 bit).
        public func setDepth(_ depth: Float) {
            BitCrusher.api.pointee.setDepth.unsafelyUnwrapped(pointer, depth)
        }

        public var depthModulator: SignalValue? {
            get { SignalValue.wrap(BitCrusher.api.pointee.getDepthModulator.unsafelyUnwrapped(pointer)) }
            set {
                retain(newValue)
                BitCrusher.api.pointee.setDepthModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        /// The amount of downsampling, 0 (none) to 1 (every sample repeated).
        public func setDownsampling(_ downsampling: Float) {
            BitCrusher.api.pointee.setDownsampling.unsafelyUnwrapped(pointer, downsampling)
        }

        public var downsamplingModulator: SignalValue? {
            get { SignalValue.wrap(BitCrusher.api.pointee.getDownsamplingModulator.unsafelyUnwrapped(pointer)) }
            set {
                retain(newValue)
                BitCrusher.api.pointee.setDownsamplingModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        private func retain(_ modulator: SignalValue?) {
            if let modulator { retainedModulators.append(modulator) }
        }
    }

    // MARK: - Ring modulator

    /// A ring modulator effect. Wraps `RingModulator`.
    public final class RingModulator: Effect {
        private static var api: UnsafePointer<playdate_sound_effect_ringmodulator> { effectAPI.pointee.ringmodulator.unsafelyUnwrapped }

        private var retainedFrequencyModulator: SignalValue?

        public init() {
            super.init(pointer: RingModulator.api.pointee.newRingmod.unsafelyUnwrapped().unsafelyUnwrapped,
                       isOwned: true)
        }

        deinit {
            if isOwned {
                RingModulator.api.pointee.freeRingmod.unsafelyUnwrapped(pointer)
            }
        }

        /// The modulation frequency, in Hz.
        public func setFrequency(_ frequency: Float) {
            RingModulator.api.pointee.setFrequency.unsafelyUnwrapped(pointer, frequency)
        }

        public var frequencyModulator: SignalValue? {
            get { SignalValue.wrap(RingModulator.api.pointee.getFrequencyModulator.unsafelyUnwrapped(pointer)) }
            set {
                retainedFrequencyModulator = newValue
                RingModulator.api.pointee.setFrequencyModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }
    }

    // MARK: - Delay line

    /// A tap into a delay line; produces audio and can be added to a channel
    /// as a source. Wraps `DelayLineTap`.
    public final class DelayLineTap: Source {
        private static var api: UnsafePointer<playdate_sound_effect_delayline> { effectAPI.pointee.delayline.unsafelyUnwrapped }

        /// The delay line is retained so the tap stays valid.
        private let delayLine: DelayLine
        private var retainedDelayModulator: SignalValue?

        init(pointer: OpaquePointer, delayLine: DelayLine) {
            self.delayLine = delayLine
            super.init(pointer: pointer, isOwned: true)
        }

        deinit {
            DelayLineTap.api.pointee.freeTap.unsafelyUnwrapped(pointer)
        }

        /// The tap's position in the delay line, in frames.
        public func setDelay(frames: Int) {
            DelayLineTap.api.pointee.setTapDelay.unsafelyUnwrapped(pointer, Int32(frames))
        }

        public var delayModulator: SignalValue? {
            get { SignalValue.wrap(DelayLineTap.api.pointee.getTapDelayModulator.unsafelyUnwrapped(pointer)) }
            set {
                retainedDelayModulator = newValue
                DelayLineTap.api.pointee.setTapDelayModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        /// For stereo delay lines: swaps the left and right channels.
        public func setChannelsFlipped(_ flipped: Bool) {
            DelayLineTap.api.pointee.setTapChannelsFlipped.unsafelyUnwrapped(pointer, flipped ? 1 : 0)
        }
    }

    /// A delay line effect. Wraps `DelayLine`.
    public final class DelayLine: Effect {
        private static var api: UnsafePointer<playdate_sound_effect_delayline> { effectAPI.pointee.delayline.unsafelyUnwrapped }

        /// Creates a delay line holding `length` frames.
        public init(length: Int, stereo: Bool = false) {
            super.init(pointer: DelayLine.api.pointee.newDelayLine.unsafelyUnwrapped(
                Int32(length), stereo ? 1 : 0).unsafelyUnwrapped, isOwned: true)
        }

        deinit {
            if isOwned {
                DelayLine.api.pointee.freeDelayLine.unsafelyUnwrapped(pointer)
            }
        }

        /// Changes the delay length. Cannot be larger than the line's
        /// original length.
        public func setLength(frames: Int) {
            DelayLine.api.pointee.setLength.unsafelyUnwrapped(pointer, Int32(frames))
        }

        /// The feedback level, 0...1.
        public func setFeedback(_ feedback: Float) {
            DelayLine.api.pointee.setFeedback.unsafelyUnwrapped(pointer, feedback)
        }

        /// Adds a tap `delay` frames behind the write head. The tap can be
        /// added to a channel as a sound source.
        public func addTap(delay: Int) -> DelayLineTap? {
            guard let tap = DelayLine.api.pointee.addTap.unsafelyUnwrapped(pointer, Int32(delay)) else {
                return nil
            }
            return DelayLineTap(pointer: tap, delayLine: self)
        }
    }

    // MARK: - Overdrive

    /// An overdrive/distortion effect. Wraps `Overdrive`.
    public final class Overdrive: Effect {
        private static var api: UnsafePointer<playdate_sound_effect_overdrive> { effectAPI.pointee.overdrive.unsafelyUnwrapped }

        private var retainedModulators: [SignalValue] = []

        public init() {
            super.init(pointer: Overdrive.api.pointee.newOverdrive.unsafelyUnwrapped().unsafelyUnwrapped,
                       isOwned: true)
        }

        deinit {
            if isOwned {
                Overdrive.api.pointee.freeOverdrive.unsafelyUnwrapped(pointer)
            }
        }

        /// The input gain applied before clipping.
        public func setGain(_ gain: Float) {
            Overdrive.api.pointee.setGain.unsafelyUnwrapped(pointer, gain)
        }

        /// The level where the amplified input clips.
        public func setLimit(_ limit: Float) {
            Overdrive.api.pointee.setLimit.unsafelyUnwrapped(pointer, limit)
        }

        public var limitModulator: SignalValue? {
            get { SignalValue.wrap(Overdrive.api.pointee.getLimitModulator.unsafelyUnwrapped(pointer)) }
            set {
                retain(newValue)
                Overdrive.api.pointee.setLimitModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        /// A DC offset applied to the input, making the clipping asymmetric.
        public func setOffset(_ offset: Float) {
            Overdrive.api.pointee.setOffset.unsafelyUnwrapped(pointer, offset)
        }

        public var offsetModulator: SignalValue? {
            get { SignalValue.wrap(Overdrive.api.pointee.getOffsetModulator.unsafelyUnwrapped(pointer)) }
            set {
                retain(newValue)
                Overdrive.api.pointee.setOffsetModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        private func retain(_ modulator: SignalValue?) {
            if let modulator { retainedModulators.append(modulator) }
        }
    }
}
