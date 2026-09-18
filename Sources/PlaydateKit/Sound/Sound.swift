internal import CPlaydate

/// The cached `playdate->sound` C API table.
var snd: UnsafePointer<playdate_sound> { Playdate.soundAPI.unsafelyUnwrapped }

/// The sound API: channels, players, synths, sequences, and effects.
public enum Sound {}

extension Sound {
    /// Middle C (`NOTE_C4`).
    public static let noteC4: MIDINote = 60

    /// Audio frames rendered per audio cycle (`AUDIO_FRAMES_PER_CYCLE`).
    public static let audioFramesPerCycle = 512

    /// Converts a MIDI note to a frequency in Hz.
    public static func frequency(forNote note: MIDINote) -> Float {
        pd_noteToFrequency(note)
    }

    /// Converts a frequency in Hz to a MIDI note.
    public static func note(forFrequency frequency: Float) -> MIDINote {
        pd_frequencyToNote(frequency)
    }

    /// The last sound error, as a `PlaydateError`.
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

    /// Removes `source` from its channel; `false` if it wasn't in one. Also releases a
    /// `CallbackSource`'s callback.
    @discardableResult
    public static func removeSource(_ source: Source) -> Bool {
        let removed = snd.pointee.removeSource.unsafelyUnwrapped(source.pointer) != 0
        CallbackSource.release(source)
        return removed
    }

    /// `callback` gets mono 16-bit mic samples each audio cycle and returns `false` to stop;
    /// `nil` stops now. Returns `false` on error, e.g. access denied (`requestMicAccess`).
    @discardableResult
    public static func setMicCallback(source: MicSource = .autodetect,
                                      _ callback: ((Span<Int16>) -> Bool)?) -> Bool {
        micCallback = callback
        if callback != nil {
            return snd.pointee.setMicCallback.unsafelyUnwrapped({ _, buffer, length in
                let samples = UnsafeBufferPointer(start: buffer, count: Int(length)).span
                return Sound.micCallback?(samples) == true ? 1 : 0
            }, nil, CPlaydate.MicSource(CPlaydate.MicSource.RawValue(source.rawValue))) != 0
        } else {
            return snd.pointee.setMicCallback.unsafelyUnwrapped(nil, nil, CPlaydate.MicSource(CPlaydate.MicSource.RawValue(source.rawValue))) != 0
        }
    }

    nonisolated(unsafe) private static var micCallback: ((Span<Int16>) -> Bool)?

    /// Asks for mic permission before `setMicCallback`; `purpose` is shown in the prompt.
    /// `completion` gets the answer only when this returns `.ask` (else already known).
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
            reply = purpose.withCString {
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

    /// Called when headphone or headset-mic state changes; `nil` removes it. While set,
    /// output doesn't auto-switch speaker/headphones; call `setOutputsActive` from it.
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

    /// Forces audio output to the given outputs, regardless of headphone state.
    public static func setOutputsActive(headphone: Bool, speaker: Bool) {
        snd.pointee.setOutputsActive.unsafelyUnwrapped(headphone ? 1 : 0, speaker ? 1 : 0)
    }

    /// Adds a `CallbackSource` to the default channel.
    public static func addSource(stereo: Bool,
                                 _ callback: @escaping CallbackSource.Callback) -> CallbackSource {
        let source = CallbackSource(callback: callback)
        let pointer = snd.pointee.addSource.unsafelyUnwrapped(
            CallbackSource.trampoline, source.contextPointer, stereo ? 1 : 0)
        source.adopt(pointer: pointer.unsafelyUnwrapped)
        return source
    }
}
