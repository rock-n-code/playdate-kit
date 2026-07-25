public import CPlaydate

/// A Swift view of `PDSystemEvent` with the key code folded into the
/// key events.
public enum SystemEvent {
    /// Sent once at startup, before the first update.
    case initialize
    /// Sent when the Lua runtime is ready, for registering custom
    /// functions and classes.
    case initializeLua
    /// The device was locked.
    case lock
    /// The device was unlocked.
    case unlock
    /// The game was paused (e.g. the system menu opened).
    case pause
    /// The game resumed after a pause.
    case resume
    /// The game is about to be terminated.
    case terminate
    /// A simulator key was pressed.
    case keyPressed(keyCode: UInt32)
    /// A simulator key was released.
    case keyReleased(keyCode: UInt32)
    /// The device is about to power down because the battery is low.
    case lowPower
    /// A Mirror session started.
    case mirrorStarted
    /// A Mirror session ended.
    case mirrorEnded

    /// Creates an event from the C event and its argument, or `nil` for
    /// events unknown to this binding.
    public init?(event: PDSystemEvent, argument: UInt32) {
        switch event {
        case kEventInit: self = .initialize
        case kEventInitLua: self = .initializeLua
        case kEventLock: self = .lock
        case kEventUnlock: self = .unlock
        case kEventPause: self = .pause
        case kEventResume: self = .resume
        case kEventTerminate: self = .terminate
        case kEventKeyPressed: self = .keyPressed(keyCode: argument)
        case kEventKeyReleased: self = .keyReleased(keyCode: argument)
        case kEventLowPower: self = .lowPower
        case kEventMirrorStarted: self = .mirrorStarted
        case kEventMirrorEnded: self = .mirrorEnded
        default: return nil
        }
    }
}
