internal import CPlaydate

extension Sound {
    /// A mixer channel holding sources and effects. Wraps `SoundChannel`.
    public final class Channel {
        private static var api: UnsafePointer<playdate_sound_channel> { Playdate.channelAPI.unsafelyUnwrapped }

        let pointer: OpaquePointer
        let isOwned: Bool
        private var retainedSources: [Source] = []
        private var retainedEffects: [Effect] = []
        private var retainedModulators: [SignalValue] = []

        init(pointer: OpaquePointer, isOwned: Bool) {
            self.pointer = pointer
            self.isOwned = isOwned
        }

        /// Creates a new channel. Add it to the sound engine with `add()`.
        public convenience init() {
            self.init(pointer: Channel.api.pointee.newChannel.unsafelyUnwrapped().unsafelyUnwrapped,
                      isOwned: true)
        }

        deinit {
            if isOwned {
                Channel.api.pointee.freeChannel.unsafelyUnwrapped(pointer)
                // The freed channel no longer pulls its callback sources, so
                // their trampoline registrations can be released too.
                for source in retainedSources where source is CallbackSource {
                    CallbackSource.release(source)
                }
            }
        }

        /// The default channel, which sources are added to unless otherwise
        /// specified. A single shared wrapper, so resources retained through
        /// it (sources, effects, modulators) stay alive.
        public static var `default`: Channel { defaultChannel }

        nonisolated(unsafe) private static let defaultChannel =
            Channel(pointer: snd.pointee.getDefaultChannel.unsafelyUnwrapped().unsafelyUnwrapped,
                    isOwned: false)

        nonisolated(unsafe) private static var addedChannels: [Channel] = []

        /// Adds the channel to the sound engine.
        @discardableResult
        public func add() -> Bool {
            let added = snd.pointee.addChannel.unsafelyUnwrapped(pointer) != 0
            if added, !Channel.addedChannels.contains(where: { $0 === self }) {
                Channel.addedChannels.append(self)
            }
            return added
        }

        /// Removes the channel from the sound engine.
        @discardableResult
        public func remove() -> Bool {
            let removed = snd.pointee.removeChannel.unsafelyUnwrapped(pointer) != 0
            Channel.addedChannels.removeAll { $0 === self }
            return removed
        }

        /// Adds a source to the channel. A source can only be on one channel.
        @discardableResult
        public func addSource(_ source: Source) -> Bool {
            let added = Channel.api.pointee.addSource.unsafelyUnwrapped(pointer, source.pointer) != 0
            if added, !retainedSources.contains(where: { $0 === source }) {
                retainedSources.append(source)
            }
            return added
        }

        @discardableResult
        public func removeSource(_ source: Source) -> Bool {
            let removed = Channel.api.pointee.removeSource.unsafelyUnwrapped(pointer, source.pointer) != 0
            // Only drop the retentions if the source was actually on this
            // channel; otherwise another channel may still be pulling it.
            if removed {
                retainedSources.removeAll { $0 === source }
                CallbackSource.release(source)
            }
            return removed
        }

        /// Adds a callback-based source to the channel. The callback fills
        /// the sample buffers and returns `true` if it produced output.
        public func addCallbackSource(stereo: Bool,
                                      _ callback: @escaping CallbackSource.Callback) -> CallbackSource {
            let source = CallbackSource(callback: callback)
            let pointer = Channel.api.pointee.addCallbackSource.unsafelyUnwrapped(
                self.pointer, CallbackSource.trampoline, source.contextPointer, stereo ? 1 : 0)
            source.adopt(pointer: pointer.unsafelyUnwrapped)
            retainedSources.append(source)
            return source
        }

        @discardableResult
        public func addEffect(_ effect: Effect) -> Bool {
            let added = Channel.api.pointee.addEffect.unsafelyUnwrapped(pointer, effect.pointer) != 0
            if added, !retainedEffects.contains(where: { $0 === effect }) {
                retainedEffects.append(effect)
            }
            return added
        }

        @discardableResult
        public func removeEffect(_ effect: Effect) -> Bool {
            let removed = Channel.api.pointee.removeEffect.unsafelyUnwrapped(pointer, effect.pointer) != 0
            retainedEffects.removeAll { $0 === effect }
            return removed
        }

        /// The channel's volume, 0...1.
        public var volume: Float {
            get { Channel.api.pointee.getVolume.unsafelyUnwrapped(pointer) }
            set { Channel.api.pointee.setVolume.unsafelyUnwrapped(pointer, newValue) }
        }

        /// Modulates the channel's volume.
        public var volumeModulator: SignalValue? {
            get { SignalValue.wrap(Channel.api.pointee.getVolumeModulator.unsafelyUnwrapped(pointer)) }
            set {
                retain(newValue)
                Channel.api.pointee.setVolumeModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        /// The channel's stereo pan: -1 (left) to 1 (right).
        public func setPan(_ pan: Float) {
            Channel.api.pointee.setPan.unsafelyUnwrapped(pointer, pan)
        }

        /// Modulates the channel's pan. The signal's range 0...1 maps to
        /// left...right.
        public var panModulator: SignalValue? {
            get { SignalValue.wrap(Channel.api.pointee.getPanModulator.unsafelyUnwrapped(pointer)) }
            set {
                retain(newValue)
                Channel.api.pointee.setPanModulator.unsafelyUnwrapped(pointer, newValue?.pointer)
            }
        }

        /// A signal following the channel's dry (unprocessed) level.
        public var dryLevelSignal: SignalValue? {
            SignalValue.wrap(Channel.api.pointee.getDryLevelSignal.unsafelyUnwrapped(pointer))
        }

        /// A signal following the channel's wet (processed) level.
        public var wetLevelSignal: SignalValue? {
            SignalValue.wrap(Channel.api.pointee.getWetLevelSignal.unsafelyUnwrapped(pointer))
        }

        /// The channel's output as a source, for feeding into another channel.
        /// The same wrapper is returned on every access, so callbacks
        /// registered on it stay valid for the channel's lifetime.
        public var outputAsSource: Source? {
            guard let source = Channel.api.pointee.getOutputAsSource.unsafelyUnwrapped(pointer) else {
                return nil
            }
            if let cached = cachedOutputSource, cached.pointer == source {
                return cached
            }
            let wrapper = Source(pointer: source, isOwned: false)
            cachedOutputSource = wrapper
            return wrapper
        }

        private var cachedOutputSource: Source?

        private func retain(_ modulator: SignalValue?) {
            if let modulator, !retainedModulators.contains(where: { $0 === modulator }) {
                retainedModulators.append(modulator)
            }
        }
    }
}
