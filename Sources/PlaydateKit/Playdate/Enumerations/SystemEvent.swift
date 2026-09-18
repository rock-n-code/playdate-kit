public import CPlaydate

/// An event sent to the game's `eventHandler`. Wraps `PDSystemEvent`; key events carry
/// the event argument.
public enum SystemEvent {
    /// Once after the game loads, before the first update.
    case initialize
    /// After `initialize` if no update callback is set, once Lua exists and before
    /// `main.lua` runs; register Lua functions and classes here.
    case initializeLua
    case lock
    case unlock
    /// E.g. the system menu opened.
    case pause
    case resume
    case terminate
    /// Simulator only.
    case keyPressed(keyCode: UInt32)
    /// Simulator only.
    case keyReleased(keyCode: UInt32)
    /// About to enter low-power sleep because the battery is low.
    case lowPower
    /// Mirror connected.
    case mirrorStarted
    /// Mirror disconnected.
    case mirrorEnded

    /// From the `eventHandler` arguments; `nil` for events this binding doesn't know.
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
