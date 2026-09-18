public import CPlaydate

/// Raw C API bootstrap. The firmware passes the `PlaydateAPI` table to the game's
/// `eventHandler`; call `initialize(with:)` there before any other API in this module.
/// The wrappers (`System`, `Graphics`, `Sprite`, `Sound`, ...) are top-level.
public enum Playdate {
    /// Copy of the C API table; `nil` until `initialize(with:)`. Unsynchronized: the
    /// runtime is single-threaded and this is written once at startup.
    public internal(set) nonisolated(unsafe) static var api: PlaydateAPI!

    /// The pointer passed to `initialize(with:)`, for C calls that take it; `nil` until then.
    public internal(set) nonisolated(unsafe) static var apiPointer: UnsafeMutablePointer<PlaydateAPI>!

    // Cached so each wrapper call is one field load instead of re-walking `api`.
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

    // Optional chaining tolerates partial tables (e.g. test mocks) with a null parent;
    // using a missing table traps at the call site.
    nonisolated(unsafe) static var tilemapAPI: UnsafePointer<playdate_tilemap>!
    nonisolated(unsafe) static var videoAPI: UnsafePointer<playdate_video>!
    nonisolated(unsafe) static var videoStreamAPI: UnsafePointer<playdate_videostream>!
    nonisolated(unsafe) static var channelAPI: UnsafePointer<playdate_sound_channel>!
    nonisolated(unsafe) static var sourceAPI: UnsafePointer<playdate_sound_source>!
    nonisolated(unsafe) static var filePlayerAPI: UnsafePointer<playdate_sound_fileplayer>!
    nonisolated(unsafe) static var sampleAPI: UnsafePointer<playdate_sound_sample>!
    nonisolated(unsafe) static var samplePlayerAPI: UnsafePointer<playdate_sound_sampleplayer>!
    nonisolated(unsafe) static var synthAPI: UnsafePointer<playdate_sound_synth>!
    nonisolated(unsafe) static var instrumentAPI: UnsafePointer<playdate_sound_instrument>!
    nonisolated(unsafe) static var trackAPI: UnsafePointer<playdate_sound_track>!
    nonisolated(unsafe) static var sequenceAPI: UnsafePointer<playdate_sound_sequence>!
    nonisolated(unsafe) static var signalAPI: UnsafePointer<playdate_sound_signal>!
    nonisolated(unsafe) static var lfoAPI: UnsafePointer<playdate_sound_lfo>!
    nonisolated(unsafe) static var envelopeAPI: UnsafePointer<playdate_sound_envelope>!
    nonisolated(unsafe) static var controlSignalAPI: UnsafePointer<playdate_control_signal>!
    nonisolated(unsafe) static var effectAPI: UnsafePointer<playdate_sound_effect>!
    nonisolated(unsafe) static var twoPoleFilterAPI: UnsafePointer<playdate_sound_effect_twopolefilter>!
    nonisolated(unsafe) static var onePoleFilterAPI: UnsafePointer<playdate_sound_effect_onepolefilter>!
    nonisolated(unsafe) static var bitCrusherAPI: UnsafePointer<playdate_sound_effect_bitcrusher>!
    nonisolated(unsafe) static var ringModulatorAPI: UnsafePointer<playdate_sound_effect_ringmodulator>!
    nonisolated(unsafe) static var delayLineAPI: UnsafePointer<playdate_sound_effect_delayline>!
    nonisolated(unsafe) static var overdriveAPI: UnsafePointer<playdate_sound_effect_overdrive>!
    nonisolated(unsafe) static var httpAPI: UnsafePointer<playdate_http>!
    nonisolated(unsafe) static var tcpAPI: UnsafePointer<playdate_tcp>!

    /// Stores the `eventHandler`'s `PlaydateAPI*` and caches its sub-tables. Call on the
    /// `.initialize` event, before any other API in this module.
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
        tilemapAPI = graphicsAPI?.pointee.tilemap
        videoAPI = graphicsAPI?.pointee.video
        videoStreamAPI = graphicsAPI?.pointee.videostream
        channelAPI = soundAPI?.pointee.channel
        sourceAPI = soundAPI?.pointee.source
        filePlayerAPI = soundAPI?.pointee.fileplayer
        sampleAPI = soundAPI?.pointee.sample
        samplePlayerAPI = soundAPI?.pointee.sampleplayer
        synthAPI = soundAPI?.pointee.synth
        instrumentAPI = soundAPI?.pointee.instrument
        trackAPI = soundAPI?.pointee.track
        sequenceAPI = soundAPI?.pointee.sequence
        signalAPI = soundAPI?.pointee.signal
        lfoAPI = soundAPI?.pointee.lfo
        envelopeAPI = soundAPI?.pointee.envelope
        controlSignalAPI = soundAPI?.pointee.controlsignal
        effectAPI = soundAPI?.pointee.effect
        twoPoleFilterAPI = effectAPI?.pointee.twopolefilter
        onePoleFilterAPI = effectAPI?.pointee.onepolefilter
        bitCrusherAPI = effectAPI?.pointee.bitcrusher
        ringModulatorAPI = effectAPI?.pointee.ringmodulator
        delayLineAPI = effectAPI?.pointee.delayline
        overdriveAPI = effectAPI?.pointee.overdrive
        httpAPI = networkAPI?.pointee.http
        tcpAPI = networkAPI?.pointee.tcp
    }
}
