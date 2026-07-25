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
@testable import PlaydateKit

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

    @Test func bitmapTableIsACollection() {
        let table = Graphics.BitmapTable(count: 4, width: 8, height: 8)
        #expect(table.count == 1)   // the mock reports a single bitmap
        #expect(table.first != nil)

        var visited = 0
        for _ in table { visited += 1 }
        #expect(visited == 1)
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

    // MARK: Sound ownership graph

    @Test func channelRetainsAddedSourceUntilRemoved() {
        let channel = Sound.Channel()
        weak var weakSynth: Sound.Synth?
        do {
            let synth = Sound.Synth()
            weakSynth = synth
            channel.addSource(synth)
        }
        #expect(weakSynth != nil)   // the channel keeps the source alive
        #expect(Mock.eventCount("freeSynth") == 0)

        if let synth = weakSynth {
            channel.removeSource(synth)
        }
        #expect(weakSynth == nil)
        #expect(Mock.eventCount("freeSynth") == 1)
    }

    @Test func synthRetainsItsModulatorWhileAlive() {
        weak var weakLFO: Sound.LFO?
        do {
            let synth = Sound.Synth()
            do {
                let lfo = Sound.LFO()
                weakLFO = lfo
                synth.frequencyModulator = lfo
            }
            #expect(weakLFO != nil)   // the synth retains the modulator
            #expect(Mock.eventCount("freeLFO") == 0)
        }
        #expect(weakLFO == nil)
        #expect(Mock.eventCount("freeLFO") == 1)
    }

    @Test func synthGeneratorDispatchesAndIsReleasedWithTheSynth() {
        final class Token {}
        weak var weakToken: Token?
        var rendered = 0

        do {
            let synth = Sound.Synth()
            let token = Token()
            weakToken = token
            synth.setGenerator(stereo: false, .init(render: { left, _, _, _ in
                _ = token
                rendered += 1
                return left.count
            }))

            // Simulate the audio engine rendering through the trampoline.
            let generator = try! #require(Mock.synthGenerators[synth.pointer])
            var samples = [Int32](repeating: 0, count: 8)
            let frames = samples.withUnsafeMutableBufferPointer { buffer in
                generator.render?(generator.userdata, buffer.baseAddress, nil,
                                  Int32(buffer.count), 0, 0)
            }
            #expect(frames == 8)
            #expect(rendered == 1)
            #expect(weakToken != nil)
        }
        // freeSynth deallocs the generator userdata, releasing the box and
        // the closure's captures with it.
        #expect(Mock.eventCount("freeSynth") == 1)
        #expect(weakToken == nil)
    }

    @Test func replacingASynthGeneratorReleasesThePreviousOne() {
        final class Token {}
        weak var firstToken: Token?

        let synth = Sound.Synth()
        do {
            let token = Token()
            firstToken = token
            synth.setGenerator(stereo: false, .init(render: { left, _, _, _ in
                _ = token
                return left.count
            }))
        }
        #expect(firstToken != nil)

        synth.setGenerator(stereo: false, .init(render: { left, _, _, _ in left.count }))
        #expect(firstToken == nil)   // the OS deallocs the replaced generator
    }

    @Test func effectProcessorDispatchesAndIsReleasedOnDeinit() {
        final class Token {}
        weak var weakToken: Token?
        var processed = 0

        do {
            let token = Token()
            weakToken = token
            let effect = Sound.Effect(processor: { left, right, _ in
                _ = token
                processed += left.count
                #expect(right == nil)
                return true
            })

            // Drive the effect the way the OS would: through the registered
            // proc, which recovers the box from the effect's userdata.
            var samples = [Int32](repeating: 0, count: 4)
            let active = samples.withUnsafeMutableBufferPointer { buffer in
                Mock.effectProc?(effect.pointer, buffer.baseAddress, nil,
                                 Int32(buffer.count), 1)
            }
            #expect(active == 1)
            #expect(processed == 4)
        }
        #expect(Mock.eventCount("freeEffect") == 1)
        #expect(weakToken == nil)
    }

    @Test func effectSubclassIsFreedExactlyOnceWithItsOwnFree() {
        do {
            let line = Sound.DelayLine(length: 256)
            _ = line
        }
        #expect(Mock.eventCount("freeDelayLine") == 1)
        // The base Effect deinit must not also free the subclass's object.
        #expect(Mock.eventCount("freeEffect") == 0)
    }

    @Test func delayLineTapKeepsItsDelayLineAlive() {
        weak var weakLine: Sound.DelayLine?
        var tap: Sound.DelayLineTap?
        do {
            let line = Sound.DelayLine(length: 256)
            weakLine = line
            tap = line.addTap(delay: 128)
        }
        #expect(weakLine != nil)   // the tap retains its delay line
        #expect(Mock.eventCount("freeDelayLine") == 0)

        tap = nil
        #expect(Mock.eventCount("freeTap") == 1)
        #expect(Mock.eventCount("freeDelayLine") == 1)
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

    @Test func jsonEncoderAccumulatesOutput() {
        let encoder = JSON.Encoder()
        encoder.startTable()
        encoder.addTableMember(name: "level")
        encoder.writeInt(3)
        encoder.addTableMember(name: "name")
        encoder.writeString("Röck")
        encoder.endTable()

        // The mock emits fragments verbatim, with no separators between
        // members; "Röck" exercises multi-byte UTF-8 through the byte buffer.
        #expect(encoder.json == "{\"level\":3\"name\":\"Röck\"}")
    }
}
