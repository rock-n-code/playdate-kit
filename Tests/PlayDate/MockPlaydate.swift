//
//  MockPlaydate.swift
//  A fake PlaydateAPI for host testing: real C structs whose function
//  pointers are Swift stubs that record their arguments. Only the fields
//  the tests exercise are populated; calling an unpopulated field traps.
//
//  Recording state is global (C function pointers cannot capture), so all
//  tests using this harness must run in a `.serialized` suite.
//

import CPlaydate
@testable import PlayDate

enum Mock {
    // MARK: - Stable API allocations

    nonisolated(unsafe) static let sysAPI = UnsafeMutablePointer<playdate_sys>.allocate(capacity: 1)
    nonisolated(unsafe) static let displayAPI = UnsafeMutablePointer<playdate_display>.allocate(capacity: 1)
    nonisolated(unsafe) static let gfxAPI = UnsafeMutablePointer<playdate_graphics>.allocate(capacity: 1)
    nonisolated(unsafe) static let spriteAPI = UnsafeMutablePointer<playdate_sprite>.allocate(capacity: 1)
    nonisolated(unsafe) static let soundAPI = UnsafeMutablePointer<playdate_sound>.allocate(capacity: 1)
    nonisolated(unsafe) static let channelAPI = UnsafeMutablePointer<playdate_sound_channel>.allocate(capacity: 1)
    nonisolated(unsafe) static let fileAPI = UnsafeMutablePointer<playdate_file>.allocate(capacity: 1)
    nonisolated(unsafe) static let jsonAPI = UnsafeMutablePointer<playdate_json>.allocate(capacity: 1)
    nonisolated(unsafe) static let apiStruct = UnsafeMutablePointer<PlaydateAPI>.allocate(capacity: 1)

    // MARK: - Recordings

    /// Chronological log of stub invocations, formatted per stub.
    nonisolated(unsafe) static var events: [String] = []
    nonisolated(unsafe) static var buttonState: (current: UInt32, pushed: UInt32, released: UInt32) = (0, 0, 0)
    /// The 16 bytes behind the last pattern `LCDColor` seen by a stub.
    nonisolated(unsafe) static var patternBytes: [UInt8] = []
    /// Userdata stored per sprite / menu item, as the OS would keep it.
    nonisolated(unsafe) static var spriteUserdata: [OpaquePointer: UnsafeMutableRawPointer] = [:]
    nonisolated(unsafe) static var menuUserdata: [OpaquePointer: UnsafeMutableRawPointer] = [:]
    /// Callbacks handed to the C API, for re-invocation by tests.
    nonisolated(unsafe) static var menuCallback: (@convention(c) (UnsafeMutableRawPointer?) -> Void)?
    nonisolated(unsafe) static var spriteUpdateCallback: (@convention(c) (OpaquePointer?) -> Void)?
    nonisolated(unsafe) static var audioCallback: (@convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<Int16>?, UnsafeMutablePointer<Int16>?, Int32) -> Int32)?
    nonisolated(unsafe) static var audioContext: UnsafeMutableRawPointer?

    static func record(_ event: String) {
        events.append(event)
    }

    static func eventCount(_ event: String) -> Int {
        events.filter { $0 == event }.count
    }

    // MARK: - Lifecycle

    /// Distinct fake object pointers, so identity-keyed recordings work.
    nonisolated(unsafe) private static var pointerSeed: UInt = 0x1000

    static func fakePointer() -> OpaquePointer {
        pointerSeed += 16
        return OpaquePointer(bitPattern: pointerSeed)!
    }

    /// Installs the mock API exactly once per process.
    static let ready: Void = install()

    static func resetRecordings() {
        _ = ready
        events = []
        buttonState = (0, 0, 0)
        patternBytes = []
        spriteUserdata = [:]
        menuUserdata = [:]
        menuCallback = nil
        spriteUpdateCallback = nil
        audioCallback = nil
        audioContext = nil
    }

    private static func install() {
        installSystem()
        installDisplay()
        installGraphics()
        installSprite()
        installSound()
        installFile()
        installJSON()
        apiStruct.initialize(to: PlaydateAPI(
            system: UnsafePointer(sysAPI),
            file: UnsafePointer(fileAPI),
            graphics: UnsafePointer(gfxAPI),
            sprite: UnsafePointer(spriteAPI),
            display: UnsafePointer(displayAPI),
            sound: UnsafePointer(soundAPI),
            lua: nil,
            json: UnsafePointer(jsonAPI),
            scoreboards: nil,
            network: nil))
        Playdate.initialize(with: UnsafeMutableRawPointer(apiStruct))
    }

    // MARK: - System

    private static func installSystem() {
        sysAPI.initialize(to: playdate_sys())

        // Backed by the host allocator, so wrapper-freed OS memory balances.
        sysAPI.pointee.realloc = { pointer, size in
            if size == 0 {
                if let pointer {
                    Mock.record("sysFree")
                    free(pointer)
                }
                return nil
            }
            return realloc(pointer, size)
        }

        sysAPI.pointee.getButtonState = { current, pushed, released in
            current?.pointee = PDButtons(Mock.buttonState.current)
            pushed?.pointee = PDButtons(Mock.buttonState.pushed)
            released?.pointee = PDButtons(Mock.buttonState.released)
        }

        sysAPI.pointee.addMenuItem = { title, callback, _ in
            Mock.record("addMenuItem(\(String(cString: title!)))")
            Mock.menuCallback = callback
            return Mock.fakePointer()
        }
        sysAPI.pointee.setMenuItemUserdata = { item, userdata in
            Mock.menuUserdata[item!] = userdata
        }
        sysAPI.pointee.getMenuItemUserdata = { item in
            Mock.menuUserdata[item!]
        }
        sysAPI.pointee.removeMenuItem = { _ in
            Mock.record("removeMenuItem")
        }
        sysAPI.pointee.removeAllMenuItems = {
            Mock.record("removeAllMenuItems")
        }
    }

    // MARK: - Display

    private static func installDisplay() {
        displayAPI.initialize(to: playdate_display())
        displayAPI.pointee.getWidth = { 400 }
        displayAPI.pointee.getHeight = { 240 }
    }

    // MARK: - Graphics

    private static func installGraphics() {
        gfxAPI.initialize(to: playdate_graphics())

        gfxAPI.pointee.fillRect = { x, y, width, height, color in
            if color > 3, let pattern = UnsafeRawPointer(bitPattern: color) {
                Mock.patternBytes = Array(UnsafeRawBufferPointer(start: pattern, count: 16))
                Mock.record("fillRect(\(x),\(y),\(width),\(height),pattern)")
            } else {
                Mock.record("fillRect(\(x),\(y),\(width),\(height),\(color))")
            }
        }

        gfxAPI.pointee.drawText = { text, length, encoding, x, y in
            let bytes = UnsafeRawBufferPointer(start: text, count: length)
            let string = String(decoding: bytes, as: UTF8.self)
            Mock.record("drawText(\(string),enc:\(encoding.rawValue),\(x),\(y))")
            return Int32(length)
        }

        gfxAPI.pointee.newBitmap = { width, height, _ in
            Mock.record("newBitmap(\(width)x\(height))")
            return Mock.fakePointer()
        }
        gfxAPI.pointee.freeBitmap = { _ in
            Mock.record("freeBitmap")
        }

        gfxAPI.pointee.newBitmapTable = { count, width, height in
            Mock.record("newBitmapTable(\(count))")
            return Mock.fakePointer()
        }
        gfxAPI.pointee.freeBitmapTable = { _ in
            Mock.record("freeBitmapTable")
        }
        gfxAPI.pointee.getTableBitmap = { _, index in
            Mock.record("getTableBitmap(\(index))")
            return index == 0 ? Mock.fakePointer() : nil
        }
    }

    // MARK: - Sprite

    private static func installSprite() {
        spriteAPI.initialize(to: playdate_sprite())

        spriteAPI.pointee.newSprite = {
            Mock.record("newSprite")
            return Mock.fakePointer()
        }
        spriteAPI.pointee.freeSprite = { _ in
            Mock.record("freeSprite")
        }
        spriteAPI.pointee.setUserdata = { sprite, userdata in
            Mock.spriteUserdata[sprite!] = userdata
        }
        spriteAPI.pointee.getUserdata = { sprite in
            Mock.spriteUserdata[sprite!]
        }
        spriteAPI.pointee.moveTo = { _, x, y in
            Mock.record("moveTo(\(x),\(y))")
        }
        spriteAPI.pointee.addSprite = { _ in
            Mock.record("addSprite")
        }
        spriteAPI.pointee.removeSprite = { _ in
            Mock.record("removeSprite")
        }
        spriteAPI.pointee.setUpdateFunction = { _, function in
            Mock.spriteUpdateCallback = function
        }

        spriteAPI.pointee.moveWithCollisions = { sprite, goalX, goalY, actualX, actualY, length in
            actualX?.pointee = goalX - 1
            actualY?.pointee = goalY - 2
            length?.pointee = 1
            // The wrapper frees this with the system allocator.
            let info = malloc(MemoryLayout<SpriteCollisionInfo>.stride)!
                .assumingMemoryBound(to: SpriteCollisionInfo.self)
            info.pointee = SpriteCollisionInfo(
                sprite: sprite,
                other: sprite,
                responseType: kCollisionTypeBounce,
                overlaps: 1,
                ti: 0.5,
                move: CollisionPoint(x: 1, y: 2),
                normal: CollisionVector(x: 0, y: -1),
                touch: CollisionPoint(x: 3, y: 4),
                spriteRect: PDRect(x: 0, y: 0, width: 8, height: 8),
                otherRect: PDRect(x: 8, y: 8, width: 8, height: 8))
            return info
        }
    }

    // MARK: - Sound

    private static func installSound() {
        soundAPI.initialize(to: playdate_sound())
        soundAPI.pointee.channel = UnsafePointer(channelAPI)

        soundAPI.pointee.addSource = { callback, context, _ in
            Mock.record("addSource")
            Mock.audioCallback = callback
            Mock.audioContext = context
            return Mock.fakePointer()
        }
        soundAPI.pointee.removeSource = { _ in
            Mock.record("removeSource")
            return 1
        }

        channelAPI.initialize(to: playdate_sound_channel())
        channelAPI.pointee.newChannel = {
            Mock.record("newChannel")
            return Mock.fakePointer()
        }
        channelAPI.pointee.freeChannel = { _ in
            Mock.record("freeChannel")
        }
        channelAPI.pointee.addCallbackSource = { _, callback, context, _ in
            Mock.record("addCallbackSource")
            Mock.audioCallback = callback
            Mock.audioContext = context
            return Mock.fakePointer()
        }
        channelAPI.pointee.removeSource = { _, _ in
            Mock.record("channelRemoveSource")
            return 1
        }
    }

    // MARK: - File

    private static func installFile() {
        fileAPI.initialize(to: playdate_file())

        fileAPI.pointee.geterr = { nil }
        fileAPI.pointee.open = { path, mode in
            Mock.record("open(\(String(cString: path!)),\(mode.rawValue))")
            return malloc(1)
        }
        fileAPI.pointee.close = { file in
            Mock.record("close")
            free(file)
            return 0
        }
        fileAPI.pointee.read = { _, buffer, length in
            memset(buffer, 0xAB, Int(length))
            Mock.record("read(\(length))")
            return Int32(length)
        }
        fileAPI.pointee.write = { _, _, length in
            Mock.record("write(\(length))")
            return Int32(length)
        }
    }

    // MARK: - JSON

    /// Simulates the OS parser's callback sequence for the document
    /// `{"level": 3, "name": "up", "list": [1, true]}` regardless of input.
    private static func installJSON() {
        jsonAPI.initialize(to: playdate_json())

        jsonAPI.pointee.decodeString = { decoder, _, outval in
            guard let decoder else { return 0 }

            func intValue(_ value: Int32) -> json_value {
                json_value(type: CChar(kJSONInteger.rawValue), data: .init(intval: value))
            }

            decoder.pointee.willDecodeSublist?(decoder, "_root", kJSONTable)
            decoder.pointee.didDecodeTableValue?(decoder, "level", intValue(3))

            "up".withCString { name in
                decoder.pointee.didDecodeTableValue?(
                    decoder, "name",
                    json_value(type: CChar(kJSONString.rawValue),
                               data: .init(stringval: UnsafeMutablePointer(mutating: name))))
            }

            decoder.pointee.willDecodeSublist?(decoder, "list", kJSONArray)
            decoder.pointee.didDecodeArrayValue?(decoder, 1, intValue(1))
            decoder.pointee.didDecodeArrayValue?(
                decoder, 2, json_value(type: CChar(kJSONTrue.rawValue), data: .init(intval: 0)))
            let list = decoder.pointee.didDecodeSublist?(decoder, "list", kJSONArray)
            decoder.pointee.didDecodeTableValue?(
                decoder, "list",
                json_value(type: CChar(kJSONArray.rawValue), data: .init(arrayval: list)))

            let root = decoder.pointee.didDecodeSublist?(decoder, "_root", kJSONTable)
            outval?.pointee = json_value(type: CChar(kJSONTable.rawValue),
                                         data: .init(tableval: root))
            return 1
        }
    }
}
