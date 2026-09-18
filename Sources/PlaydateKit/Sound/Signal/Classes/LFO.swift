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

        /// In cycles per second.
        public func setRate(_ rate: Float) {
            LFO.api.pointee.setRate.unsafelyUnwrapped(pointer, rate)
        }

        /// 0...1.
        public func setPhase(_ phase: Float) {
            LFO.api.pointee.setPhase.unsafelyUnwrapped(pointer, phase)
        }

        /// 0...1; used when the LFO is retriggered.
        public func setStartPhase(_ phase: Float) {
            LFO.api.pointee.setStartPhase.unsafelyUnwrapped(pointer, phase)
        }

        public func setCenter(_ center: Float) {
            LFO.api.pointee.setCenter.unsafelyUnwrapped(pointer, center)
        }

        /// The output's amplitude around its center.
        public func setDepth(_ depth: Float) {
            LFO.api.pointee.setDepth.unsafelyUnwrapped(pointer, depth)
        }

        /// Switches to `.arpeggiator` over `steps`, in half-steps from the center note
        /// (e.g. `[0, 4, 7, 12]` for a major chord).
        public func setArpeggiation(_ steps: [Float]) {
            var steps = steps
            steps.withUnsafeMutableBufferPointer { buffer in
                LFO.api.pointee.setArpeggiation.unsafelyUnwrapped(pointer, Int32(buffer.count),
                                                          buffer.baseAddress)
            }
        }

        /// For `.function` LFOs; `interpolate` smooths between calls. Keeps `function` alive.
        public func setFunction(interpolate: Bool = false, _ function: @escaping (LFO) -> Float) {
            self.function = function
            LFO.api.pointee.setFunction.unsafelyUnwrapped(pointer, { _, userdata in
                guard let userdata else { return 0 }
                let lfo = Unmanaged<LFO>.fromOpaque(userdata).takeUnretainedValue()
                return lfo.function?(lfo) ?? 0
            }, Unmanaged.passUnretained(self).toOpaque(), interpolate ? 1 : 0)
        }

        /// Holds at center `holdoff` seconds after a note starts, then ramps linearly to
        /// full depth over `rampTime` seconds.
        public func setDelay(holdoff: Float, rampTime: Float) {
            LFO.api.pointee.setDelay.unsafelyUnwrapped(pointer, holdoff, rampTime)
        }

        /// If `true`, notes on a synth using the LFO reset its phase to the start phase.
        public func setRetrigger(_ flag: Bool) {
            LFO.api.pointee.setRetrigger.unsafelyUnwrapped(pointer, flag ? 1 : 0)
        }

        /// If `true`, updates continuously, even when not in use.
        public func setGlobal(_ global: Bool) {
            LFO.api.pointee.setGlobal.unsafelyUnwrapped(pointer, global ? 1 : 0)
        }

        /// Seeds the random generator, for reproducible `.sampleAndHold` output.
        public func setRandomSeed(_ seed: UInt16) {
            LFO.api.pointee.setRandomSeed.unsafelyUnwrapped(pointer, seed)
        }

        public var value: Float {
            LFO.api.pointee.getValue.unsafelyUnwrapped(pointer)
        }
    }
}
