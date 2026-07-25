//
//  Sound.swift
//  Wraps `playdate->sound` (pd_api_sound.h): the namespace, top-level audio
//  functions, and SoundChannel. Sources, signals, synths, and effects live in
//  their own files.
//

internal import CPlaydate

var snd: UnsafePointer<playdate_sound> { Playdate.soundAPI.unsafelyUnwrapped }

/// The sound API: channels, players, synths, sequences, and effects.
public enum Sound {}

extension Sound {
    /// A note as a MIDI note number, where 60 is middle C. Fractional values
    /// are valid.
    public typealias MIDINote = Float

    /// Middle C (`NOTE_C4`).
    public static let noteC4: MIDINote = 60

    /// The number of audio frames rendered per system audio cycle
    /// (`AUDIO_FRAMES_PER_CYCLE`).
    public static let audioFramesPerCycle = 512

    /// Converts a MIDI note to a frequency in Hz.
    public static func frequency(forNote note: MIDINote) -> Float {
        pd_noteToFrequency(note)
    }

    /// Converts a frequency in Hz to a MIDI note.
    public static func note(forFrequency frequency: Float) -> MIDINote {
        pd_frequencyToNote(frequency)
    }

    /// The format of sample data.
    public enum Format: UInt32, Sendable {
        case mono8bit = 0
        case stereo8bit = 1
        case mono16bit = 2
        case stereo16bit = 3
        case monoADPCM = 4
        case stereoADPCM = 5

        init(_ format: SoundFormat) { self = Format(rawValue: UInt32(format.rawValue)) ?? .mono16bit }
        var cValue: SoundFormat { SoundFormat(SoundFormat.RawValue(rawValue)) }

        public var isStereo: Bool { rawValue & 1 != 0 }
        public var is16bit: Bool { rawValue >= 2 && rawValue < 4 }
        public var bytesPerFrame: Int { Int(SoundFormat_bytesPerFrame(cValue)) }
    }

    /// The microphone used when recording.
    public enum MicSource: UInt32, Sendable {
        case autodetect = 0
        case internalMic = 1
        case headset = 2
    }

    /// The most recent sound error as a thrown error.
    static func lastError() -> PlaydateError {
        PlaydateError(cString: snd.pointee.getError.unsafelyUnwrapped())
    }

    // MARK: - Top-level functions

    /// The audio engine's current time, in frames (44,100 per second).
    public static var currentTime: UInt32 {
        snd.pointee.getCurrentTime.unsafelyUnwrapped()
    }

    /// The most recent audio error message, if any.
    public static var error: String? {
        String(playdateCString: snd.pointee.getError.unsafelyUnwrapped())
    }

    /// Removes a source from its channel.
    @discardableResult
    public static func removeSource(_ source: Source) -> Bool {
        let removed = snd.pointee.removeSource.unsafelyUnwrapped(source.pointer) != 0
        CallbackSource.release(source)
        return removed
    }

    /// Sets a callback that records microphone input. Return `false` from the
    /// callback to stop recording. Pass `nil` to stop recording immediately.
    /// The buffer contains mono 16-bit samples.
    @discardableResult
    public static func setMicCallback(source: MicSource = .autodetect,
                                      _ callback: ((UnsafeMutableBufferPointer<Int16>) -> Bool)?) -> Bool {
        micCallback = callback
        if callback != nil {
            return snd.pointee.setMicCallback.unsafelyUnwrapped({ _, buffer, length in
                let samples = UnsafeMutableBufferPointer(start: buffer, count: Int(length))
                return Sound.micCallback?(samples) == true ? 1 : 0
            }, nil, CPlaydate.MicSource(CPlaydate.MicSource.RawValue(source.rawValue))) != 0
        } else {
            return snd.pointee.setMicCallback.unsafelyUnwrapped(nil, nil, CPlaydate.MicSource(CPlaydate.MicSource.RawValue(source.rawValue))) != 0
        }
    }

    nonisolated(unsafe) private static var micCallback: ((UnsafeMutableBufferPointer<Int16>) -> Bool)?

    /// Asks the user for permission to record from the microphone. `purpose`
    /// is shown in the permission prompt. The completion receives whether
    /// access was granted; it is not called if the reply was already
    /// determined (the returned value is `.deny` or `.allow`).
    @discardableResult
    public static func requestMicAccess(purpose: String? = nil,
                                        _ completion: @escaping (Bool) -> Void) -> AccessReply {
        final class Box { let body: (Bool) -> Void; init(_ body: @escaping (Bool) -> Void) { self.body = body } }
        let box = Unmanaged.passRetained(Box(completion))
        let trampoline: @convention(c) (Bool, UnsafeMutableRawPointer?) -> Void = { allowed, userdata in
            guard let userdata else { return }
            let box = Unmanaged<Box>.fromOpaque(userdata).takeRetainedValue()
            box.body(allowed)
        }
        let reply: accessReply
        if let purpose {
            reply = purpose.withPlaydateCString {
                snd.pointee.requestMicAccess.unsafelyUnwrapped($0, trampoline, box.toOpaque())
            }
        } else {
            reply = snd.pointee.requestMicAccess.unsafelyUnwrapped(nil, trampoline, box.toOpaque())
        }
        if reply != kAccessAsk {
            // The callback will not be invoked; balance the retain.
            box.release()
        }
        return AccessReply(rawValue: UInt32(reply.rawValue)) ?? .ask
    }

    /// The current headphone and headset-microphone state.
    public static var headphoneState: (headphone: Bool, headsetMic: Bool) {
        var headphone: Int32 = 0, headsetMic: Int32 = 0
        snd.pointee.getHeadphoneState.unsafelyUnwrapped(&headphone, &headsetMic, nil)
        return (headphone != 0, headsetMic != 0)
    }

    /// Installs a callback invoked when the headphone or headset-mic state
    /// changes.
    public static func setHeadphoneChangeCallback(_ callback: ((_ headphone: Bool, _ headsetMic: Bool) -> Void)?) {
        headphoneChangeCallback = callback
        if callback != nil {
            snd.pointee.getHeadphoneState.unsafelyUnwrapped(nil, nil, { headphone, mic in
                Sound.headphoneChangeCallback?(headphone != 0, mic != 0)
            })
        } else {
            snd.pointee.getHeadphoneState.unsafelyUnwrapped(nil, nil, nil)
        }
    }

    nonisolated(unsafe) private static var headphoneChangeCallback: ((Bool, Bool) -> Void)?

    /// Forces audio output to the headphone and/or speaker. When the
    /// headphone jack drives output and `speaker` is also set, the speaker
    /// plays too.
    public static func setOutputsActive(headphone: Bool, speaker: Bool) {
        snd.pointee.setOutputsActive.unsafelyUnwrapped(headphone ? 1 : 0, speaker ? 1 : 0)
    }

    /// Adds a callback-based source to the default channel. The callback
    /// fills the sample buffers and returns `true` if it produced output.
    /// Buffers hold 16-bit samples; `right` is non-nil only when `stereo`.
    public static func addSource(stereo: Bool,
                                 _ callback: @escaping CallbackSource.Callback) -> CallbackSource {
        let source = CallbackSource(callback: callback)
        let pointer = snd.pointee.addSource.unsafelyUnwrapped(
            CallbackSource.trampoline, source.contextPointer, stereo ? 1 : 0)
        source.adopt(pointer: pointer.unsafelyUnwrapped)
        return source
    }

    // MARK: - Channels

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
        public func setVolumeModulator(_ modulator: SignalValue?) {
            retain(modulator)
            Channel.api.pointee.setVolumeModulator.unsafelyUnwrapped(pointer, modulator?.pointer)
        }

        public var volumeModulator: SignalValue? {
            SignalValue.wrap(Channel.api.pointee.getVolumeModulator.unsafelyUnwrapped(pointer))
        }

        /// The channel's stereo pan: -1 (left) to 1 (right).
        public func setPan(_ pan: Float) {
            Channel.api.pointee.setPan.unsafelyUnwrapped(pointer, pan)
        }

        /// Modulates the channel's pan. The signal's range 0...1 maps to
        /// left...right.
        public func setPanModulator(_ modulator: SignalValue?) {
            retain(modulator)
            Channel.api.pointee.setPanModulator.unsafelyUnwrapped(pointer, modulator?.pointer)
        }

        public var panModulator: SignalValue? {
            SignalValue.wrap(Channel.api.pointee.getPanModulator.unsafelyUnwrapped(pointer))
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
