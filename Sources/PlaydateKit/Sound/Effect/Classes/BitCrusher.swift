internal import CPlaydate

extension Sound {
    /// A bit-crushing and downsampling effect. Wraps `BitCrusher`.
    public final class BitCrusher: Effect {
        private static var api: UnsafePointer<playdate_sound_effect_bitcrusher> { Playdate.bitCrusherAPI.unsafelyUnwrapped }

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
}
