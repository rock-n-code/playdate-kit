internal import CPlaydate

private var effectAPI: UnsafePointer<playdate_sound_effect> { Playdate.effectAPI.unsafelyUnwrapped }

extension Sound {
    /// An effect that processes a channel's audio: the base class of the
    /// built-in effects. Wraps `SoundEffect`.
    public class Effect {
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
}
