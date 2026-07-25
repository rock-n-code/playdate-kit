internal import CPlaydate

extension Sound {
    /// A low-frequency oscillator signal. Wraps `PDSynthLFO`.
    public final class LFO: SignalValue {
        private static var api: UnsafePointer<playdate_sound_lfo> { Playdate.lfoAPI.unsafelyUnwrapped }

        var function: ((LFO) -> Float)?

        public init(shape: Shape = .sine) {
            let pointer = LFO.api.pointee.newLFO.unsafelyUnwrapped(shape.cValue)
            super.init(pointer: pointer.unsafelyUnwrapped, isOwned: true)
        }

        deinit {
            if isOwned {
                LFO.api.pointee.freeLFO.unsafelyUnwrapped(pointer)
            }
        }

        public func setShape(_ shape: Shape) {
            LFO.api.pointee.setType.unsafelyUnwrapped(pointer, shape.cValue)
        }

        /// The LFO rate, in cycles per second.
        public func setRate(_ rate: Float) {
            LFO.api.pointee.setRate.unsafelyUnwrapped(pointer, rate)
        }

        /// The current phase, 0...1.
        public func setPhase(_ phase: Float) {
            LFO.api.pointee.setPhase.unsafelyUnwrapped(pointer, phase)
        }

        /// The phase the LFO starts at when a note starts, 0...1.
        public func setStartPhase(_ phase: Float) {
            LFO.api.pointee.setStartPhase.unsafelyUnwrapped(pointer, phase)
        }

        /// The center value of the LFO output.
        public func setCenter(_ center: Float) {
            LFO.api.pointee.setCenter.unsafelyUnwrapped(pointer, center)
        }

        /// The amplitude of the LFO around its center.
        public func setDepth(_ depth: Float) {
            LFO.api.pointee.setDepth.unsafelyUnwrapped(pointer, depth)
        }

        /// For `.arpeggiator` LFOs: the sequence of values (in half-steps)
        /// to step through.
        public func setArpeggiation(_ steps: [Float]) {
            var steps = steps
            steps.withUnsafeMutableBufferPointer { buffer in
                LFO.api.pointee.setArpeggiation.unsafelyUnwrapped(pointer, Int32(buffer.count),
                                                          buffer.baseAddress)
            }
        }

        /// For `.function` LFOs: the Swift function providing the value. If
        /// `interpolate` is `true`, values are interpolated between calls.
        public func setFunction(interpolate: Bool = false, _ function: @escaping (LFO) -> Float) {
            self.function = function
            LFO.api.pointee.setFunction.unsafelyUnwrapped(pointer, { _, userdata in
                guard let userdata else { return 0 }
                let lfo = Unmanaged<LFO>.fromOpaque(userdata).takeUnretainedValue()
                return lfo.function?(lfo) ?? 0
            }, Unmanaged.passUnretained(self).toOpaque(), interpolate ? 1 : 0)
        }

        /// Waits `holdoff` seconds after a note starts, then ramps the LFO
        /// depth up over `rampTime` seconds.
        public func setDelay(holdoff: Float, rampTime: Float) {
            LFO.api.pointee.setDelay.unsafelyUnwrapped(pointer, holdoff, rampTime)
        }

        /// Whether the LFO phase restarts on every new note.
        public func setRetrigger(_ flag: Bool) {
            LFO.api.pointee.setRetrigger.unsafelyUnwrapped(pointer, flag ? 1 : 0)
        }

        /// When `true`, the LFO runs globally instead of per-note.
        public func setGlobal(_ global: Bool) {
            LFO.api.pointee.setGlobal.unsafelyUnwrapped(pointer, global ? 1 : 0)
        }

        /// Seeds the random number generator used by `.sampleAndHold` LFOs.
        public func setRandomSeed(_ seed: UInt16) {
            LFO.api.pointee.setRandomSeed.unsafelyUnwrapped(pointer, seed)
        }

        /// The LFO's current value.
        public var value: Float {
            LFO.api.pointee.getValue.unsafelyUnwrapped(pointer)
        }
    }
}
