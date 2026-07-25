//
//  WrapperTests.swift
//  Exercises the wrapper plumbing against the mock PlaydateAPI: argument
//  forwarding, type conversions, callback trampolines, ownership, and
//  registry lifecycles.
//
//  Serialized because the mock's recording state is global (C function
//  pointers cannot capture context).
//

import CPlaydate
import Testing
@testable import PlayDate

@Suite(.serialized)
struct WrapperTests {
    init() {
        Mock.resetRecordings()
    }

    // MARK: System

    @Test func buttonStateConvertsMasks() {
        Mock.buttonState = (current: kButtonA.rawValue | kButtonUp.rawValue,
                            pushed: kButtonB.rawValue,
                            released: kButtonLeft.rawValue)

        let (current, pushed, released) = System.buttonState
        #expect(current == [.a, .up])
        #expect(pushed == .b)
        #expect(released == .left)
    }

    @Test func menuItemCallbackDispatchesToClosure() {
        var selections = 0
        let item = System.addMenuItem(title: "reset") { _ in selections += 1 }
        #expect(item != nil)
        #expect(Mock.events.contains("addMenuItem(reset)"))

        // Simulate the user selecting the item: the OS invokes the recorded
        // trampoline with the item's stored userdata.
        let userdata = Mock.menuUserdata[item!.pointer]
        #expect(userdata != nil)
        Mock.menuCallback?(userdata)
        Mock.menuCallback?(userdata)
        #expect(selections == 2)

        System.removeAllMenuItems()
        #expect(Mock.events.contains("removeAllMenuItems"))
    }

    // MARK: Graphics

    @Test func fillRectForwardsCoordinatesAndSolidColor() {
        Graphics.fillRect(x: 10, y: 20, width: 30, height: 40, color: .black)
        #expect(Mock.events == ["fillRect(10,20,30,40,\(kColorBlack.rawValue))"])
    }

    @Test func fillRectMaterializesPatternBytes() {
        let pattern = Graphics.Pattern(rows: (1, 2, 3, 4, 5, 6, 7, 8))
        Graphics.fillRect(x: 0, y: 0, width: 8, height: 8, color: .pattern(pattern))
        #expect(Mock.events == ["fillRect(0,0,8,8,pattern)"])
        #expect(Mock.patternBytes == [1, 2, 3, 4, 5, 6, 7, 8,
                                      0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff])
    }

    @Test func drawTextSendsUTF8BytesAndLength() {
        let width = Graphics.drawText("Hëllo", x: 4, y: 6)
        #expect(Mock.events == ["drawText(Hëllo,enc:\(kUTF8Encoding.rawValue),4,6)"])
        #expect(width == "Hëllo".utf8.count)
    }

    @Test func ownedBitmapIsFreedExactlyOnceOnDeinit() {
        do {
            let bitmap = Graphics.Bitmap(width: 32, height: 16)
            _ = bitmap
        }
        #expect(Mock.eventCount("freeBitmap") == 1)
    }

    @Test func tableVendedBitmapIsNotFreedButTableIs() {
        do {
            let table = Graphics.BitmapTable(count: 4, width: 8, height: 8)
            let bitmap = table.bitmap(at: 0)
            #expect(bitmap != nil)
            #expect(table.bitmap(at: 3) == nil)   // mock returns nil past index 0
        }
        #expect(Mock.eventCount("freeBitmap") == 0)
        #expect(Mock.eventCount("freeBitmapTable") == 1)
    }

    // MARK: Sprite

    @Test func spriteUserdataRecoversWrapperInCallbacks() {
        var updated: [ObjectIdentifier] = []
        let sprite = Sprite()
        sprite.setUpdateFunction { updated.append(ObjectIdentifier($0)) }

        // Simulate the OS driving the sprite's update.
        Mock.spriteUpdateCallback?(sprite.pointer)
        #expect(updated == [ObjectIdentifier(sprite)])
    }

    @Test func spriteIsFreedOnDeinitAndNotWhileReferenced() {
        var sprite: Sprite? = Sprite()
        _ = sprite
        #expect(Mock.eventCount("freeSprite") == 0)
        sprite = nil
        #expect(Mock.eventCount("freeSprite") == 1)
    }

    @Test func moveWithCollisionsParsesInfoAndFreesTheCArray() {
        let sprite = Sprite()
        let (actual, collisions) = sprite.moveWithCollisions(goalX: 10, goalY: 20)

        #expect(actual.x == 9 && actual.y == 18)
        #expect(collisions.count == 1)
        let collision = try! #require(collisions.first)
        #expect(collision.sprite === sprite)   // recovered through userdata
        #expect(collision.other === sprite)
        #expect(collision.response == .bounce)
        #expect(collision.overlaps)
        #expect(collision.ti == 0.5)
        #expect(collision.normal == (0, -1))
        #expect(collision.spriteRect.width == 8)

        // The C info array must be returned to the system allocator.
        #expect(Mock.eventCount("sysFree") == 1)
    }

    // MARK: Sound (regression tests for the CallbackSource lifecycle)

    @Test func callbackSourceIsRetainedUntilRemovedAndDispatches() {
        let baseline = Sound.CallbackSource.live.count

        var produced = 0
        let source = Sound.addSource(stereo: false) { left, right in
            produced += left.count
            #expect(right == nil)
            return true
        }
        #expect(Sound.CallbackSource.live.count == baseline + 1)

        // Simulate the audio engine pulling samples through the trampoline.
        var samples = [Int16](repeating: 0, count: 64)
        let result = samples.withUnsafeMutableBufferPointer { buffer in
            Mock.audioCallback?(Mock.audioContext, buffer.baseAddress, nil, Int32(buffer.count))
        }
        #expect(result == 1)
        #expect(produced == 64)

        Sound.removeSource(source)
        #expect(Sound.CallbackSource.live.count == baseline)
    }

    @Test func channelCallbackSourceIsReleasedWhenChannelIsFreed() {
        let baseline = Sound.CallbackSource.live.count
        do {
            let channel = Sound.Channel()
            _ = channel.addCallbackSource(stereo: true) { _, _ in false }
            #expect(Sound.CallbackSource.live.count == baseline + 1)
        }
        #expect(Mock.eventCount("freeChannel") == 1)
        #expect(Sound.CallbackSource.live.count == baseline)
    }

    @Test func channelRemoveSourceReleasesCallbackSource() {
        let baseline = Sound.CallbackSource.live.count
        let channel = Sound.Channel()
        let source = channel.addCallbackSource(stereo: false) { _, _ in false }
        channel.removeSource(source)
        #expect(Sound.CallbackSource.live.count == baseline)
    }

    // MARK: File

    @Test func fileHandleReadsWritesAndClosesExactlyOnce() throws {
        do {
            let handle = try File.Handle(path: "save.dat", mode: [.read, .readData])
            #expect(Mock.events.first == "open(save.dat,\(kFileRead.rawValue | kFileReadData.rawValue))")

            let bytes = try handle.read(length: 8)
            #expect(bytes == [UInt8](repeating: 0xAB, count: 8))

            let written = try handle.write([1, 2, 3])
            #expect(written == 3)

            try handle.close()
        }
        // deinit after an explicit close must not close again.
        #expect(Mock.eventCount("close") == 1)
    }

    // MARK: JSON

    @Test func jsonDecodeBuildsTheValueTree() throws {
        let value = try JSON.decode("(input is ignored by the mock)")

        guard case .table(let entries) = value else {
            Issue.record("expected a table at the root, got \(value)")
            return
        }
        guard case .int(3)? = entries["level"] else {
            Issue.record("expected level == 3")
            return
        }
        guard case .string("up")? = entries["name"] else {
            Issue.record("expected name == up")
            return
        }
        guard case .array(let list)? = entries["list"], list.count == 2,
              case .int(1) = list[0], case .bool(true) = list[1] else {
            Issue.record("expected list == [1, true]")
            return
        }
    }
}
