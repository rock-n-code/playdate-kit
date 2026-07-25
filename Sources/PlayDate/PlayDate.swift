//
//  PlayDate.swift
//  Swift bindings to the Playdate C API.
//
//  The C API is delivered as a `PlaydateAPI` struct of function pointers that
//  the firmware hands to the game's `eventHandler` entry point. Call
//  `Playdate.initialize(with:)` from that entry point before using any other
//  API in this module.
//

public import CPlaydate

/// The raw C API bootstrap. Everything else in this module (System,
/// Graphics, Sprite, Sound, ...) lives at the top level of the `PlayDate`
/// module and requires `initialize(with:)` to have been called first.
public enum Playdate {
    /// The raw C API. Populated by `initialize(with:)`.
    ///
    /// Access is unsynchronized: the Playdate runtime is single-threaded and
    /// the API pointer is written exactly once at startup.
    public internal(set) nonisolated(unsafe) static var api: PlaydateAPI!

    /// The raw C API pointer handed to `initialize(with:)`, for calls that
    /// need to pass the `PlaydateAPI*` back to C.
    public internal(set) nonisolated(unsafe) static var apiPointer: UnsafeMutablePointer<PlaydateAPI>!

    // Sub-API pointers cached once at initialization, so wrapper calls are a
    // single field load off a pointer instead of re-walking `api` per call.
    nonisolated(unsafe) static var systemAPI: UnsafePointer<playdate_sys>!
    nonisolated(unsafe) static var displayAPI: UnsafePointer<playdate_display>!
    nonisolated(unsafe) static var graphicsAPI: UnsafePointer<playdate_graphics>!
    nonisolated(unsafe) static var spriteAPI: UnsafePointer<playdate_sprite>!
    nonisolated(unsafe) static var soundAPI: UnsafePointer<playdate_sound>!
    nonisolated(unsafe) static var fileAPI: UnsafePointer<playdate_file>!
    nonisolated(unsafe) static var jsonAPI: UnsafePointer<playdate_json>!
    nonisolated(unsafe) static var luaAPI: UnsafePointer<playdate_lua>!
    nonisolated(unsafe) static var scoreboardsAPI: UnsafePointer<playdate_scoreboards>!
    nonisolated(unsafe) static var networkAPI: UnsafePointer<playdate_network>!

    /// Stores the API pointer handed to the game's `eventHandler`.
    ///
    /// Call this first, on the `.initialize` event, before using any other
    /// wrapper in this module.
    public static func initialize(with pointer: UnsafeMutableRawPointer) {
        apiPointer = pointer.assumingMemoryBound(to: PlaydateAPI.self)
        api = apiPointer.pointee
        systemAPI = api.system
        displayAPI = api.display
        graphicsAPI = api.graphics
        spriteAPI = api.sprite
        soundAPI = api.sound
        fileAPI = api.file
        jsonAPI = api.json
        luaAPI = api.lua
        scoreboardsAPI = api.scoreboards
        networkAPI = api.network
    }
}

/// An error reported by the Playdate OS.
public struct PlaydateError: Swift.Error, Sendable {
    public let message: String

    init(message: String) {
        self.message = message
    }

    init(cString: UnsafePointer<CChar>?) {
        self.init(message: String(playdateCString: cString) ?? "unknown error")
    }
}

/// The user's answer to a permission request (microphone, network).
public enum AccessReply: UInt32, Sendable {
    case ask = 0
    case deny = 1
    case allow = 2
}

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
