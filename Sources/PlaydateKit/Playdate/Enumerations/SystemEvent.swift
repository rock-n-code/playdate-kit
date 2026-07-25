public import CPlaydate

/// A Swift view of `PDSystemEvent` with the key code folded into the
/// key events.
public enum SystemEvent {
    case initialize
    case initializeLua
    case lock
    case unlock
    case pause
    case resume
    case terminate
    case keyPressed(keyCode: UInt32)
    case keyReleased(keyCode: UInt32)
    case lowPower
    case mirrorStarted
    case mirrorEnded

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
