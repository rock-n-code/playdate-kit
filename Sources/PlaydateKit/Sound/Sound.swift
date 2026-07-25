internal import CPlaydate

var snd: UnsafePointer<playdate_sound> { Playdate.soundAPI.unsafelyUnwrapped }

/// The sound API: channels, players, synths, sequences, and effects.
public enum Sound {}

extension Sound {
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
}
