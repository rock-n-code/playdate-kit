internal import CPlaydate

private var effectAPI: UnsafePointer<playdate_sound_effect> { Playdate.effectAPI.unsafelyUnwrapped }

extension Sound {
    /// Processes a channel's audio; base of the built-in effects. Wraps `SoundEffect`.
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

        /// Runs `processor` each audio cycle; keeps it alive until deinit.
        public init(processor: @escaping Processor) {
            let box = Unmanaged.passRetained(ProcessorBox(processor))
            processorBox = box
            pointer = effectAPI.pointee.newEffect.unsafelyUnwrapped({ effect, left, right, nsamples, bufactive in
                guard let effect, let left,
                      let userdata = effectAPI.pointee.getUserdata.unsafelyUnwrapped(effect) else { return 0 }
                let box = Unmanaged<ProcessorBox>.fromOpaque(userdata).takeUnretainedValue()
                var leftSpan = UnsafeMutableBufferPointer(start: left, count: Int(nsamples)).mutableSpan
                var rightSpan = UnsafeMutableBufferPointer(start: right, count: right == nil ? 0 : Int(nsamples)).mutableSpan
                return box.processor(&leftSpan, &rightSpan, bufactive != 0) ? 1 : 0
            }, box.toOpaque()).unsafelyUnwrapped
            isOwned = true
        }

        deinit {
            // Subclasses free their C object themselves; freeing here would double-free.
            if let processorBox {
                if isOwned {
                    effectAPI.pointee.freeEffect.unsafelyUnwrapped(pointer)
                }
                processorBox.release()
            }
        }

        /// Wet/dry mix: 0 leaves the effect out, 1 replaces the input with its output.
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
