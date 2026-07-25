import Testing
@testable import PlaydateKit

// Most of the binding requires a running Playdate (the API struct is handed
// to the game at launch), so these tests cover the pure value types and the
// inline C helpers that work without it.

@Test func buttonsOptionSetMatchesCMasks() {
    #expect(System.Buttons.left.rawValue == 1 << 0)
    #expect(System.Buttons.right.rawValue == 1 << 1)
    #expect(System.Buttons.up.rawValue == 1 << 2)
    #expect(System.Buttons.down.rawValue == 1 << 3)
    #expect(System.Buttons.b.rawValue == 1 << 4)
    #expect(System.Buttons.a.rawValue == 1 << 5)

    let combined: System.Buttons = [.a, .up]
    #expect(combined.contains(.a))
    #expect(!combined.contains(.b))
}

@Test func graphicsRectConvertsBetweenOriginSizeAndEdges() {
    let rect = Graphics.Rect(x: 10, y: 20, width: 30, height: 40)
    #expect(rect.left == 10)
    #expect(rect.right == 40)
    #expect(rect.top == 20)
    #expect(rect.bottom == 60)

    let translated = rect.translated(dx: 5, dy: -5)
    #expect(translated.left == 15)
    #expect(translated.top == 15)

    let roundTripped = Graphics.Rect(rect.cValue)
    #expect(roundTripped.left == rect.left && roundTripped.bottom == rect.bottom)
}

@Test func spriteRectRoundTripsThroughC() {
    let rect = Rect(x: 1.5, y: 2.5, width: 3, height: 4)
    let roundTripped = Rect(rect.cValue)
    #expect(roundTripped.x == 1.5)
    #expect(roundTripped.y == 2.5)
    #expect(roundTripped.width == 3)
    #expect(roundTripped.height == 4)
}

@Test func soundFormatPropertiesMatchCMacros() {
    #expect(!Sound.Format.mono8bit.isStereo)
    #expect(Sound.Format.stereo16bit.isStereo)
    #expect(Sound.Format.mono16bit.is16bit)
    #expect(!Sound.Format.monoADPCM.is16bit)

    #expect(Sound.Format.mono8bit.bytesPerFrame == 1)
    #expect(Sound.Format.stereo8bit.bytesPerFrame == 2)
    #expect(Sound.Format.mono16bit.bytesPerFrame == 2)
    #expect(Sound.Format.stereo16bit.bytesPerFrame == 4)
}

@Test func midiNoteFrequencyConversionRoundTrips() {
    // A4 (MIDI 69) is 440 Hz.
    let a4 = Sound.frequency(forNote: 69)
    #expect(abs(a4 - 440) < 0.01)

    let note = Sound.note(forFrequency: 440)
    #expect(abs(note - 69) < 0.001)
}

@Test func cStringHelpersRoundTripUTF8() {
    let original = "héllo, wörld"
    let copy = original.copiedPlaydateCString()
    defer { copy.deallocate() }
    #expect(String(playdateCString: copy) == original)

    let viaClosure = original.withPlaydateCString { String(playdateCString: $0) }
    #expect(viaClosure == original)
}

@Test func dateTimeMirrorsCStruct() {
    let dateTime = System.DateTime(year: 2026, month: 7, day: 24, weekday: 5,
                                            hour: 12, minute: 34, second: 56)
    let roundTripped = System.DateTime(dateTime.cValue)
    #expect(roundTripped.year == 2026)
    #expect(roundTripped.month == 7)
    #expect(roundTripped.day == 24)
    #expect(roundTripped.weekday == 5)
    #expect(roundTripped.hour == 12)
    #expect(roundTripped.minute == 34)
    #expect(roundTripped.second == 56)
}
