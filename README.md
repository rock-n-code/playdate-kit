# PlayDate

Swift bindings to the [Playdate](https://play.date) C API.

The Playdate C API is delivered as a `PlaydateAPI*` struct of function
pointers that the firmware hands to your game at launch. This package wraps
that surface in idiomatic Swift: namespaced APIs, wrapper types with
ownership semantics, closures instead of function-pointer/userdata pairs,
`OptionSet`s and `enum`s instead of raw constants, and typed `throws` for
fallible calls.

All ten C subsystems are covered:

| Namespace | Wraps | Highlights |
|---|---|---|
| `Playdate.System` | `playdate->system` | input, time, menu items, logging |
| `Playdate.Display` | `playdate->display` | refresh rate, scale, mosaic, flip |
| `Playdate.Graphics` | `playdate->graphics` | drawing, `Bitmap`, `Font`, `TileMap`, video |
| `Playdate.Sprite` | `playdate->sprite` | display list, collisions, custom draw |
| `Playdate.Sound` | `playdate->sound` | players, synths, sequences, effects |
| `Playdate.File` | `playdate->file` | `Handle`, directory operations |
| `Playdate.JSON` | `playdate->json` | `Value` tree decode/encode |
| `Playdate.Lua` | `playdate->lua` | C functions, classes, stack access |
| `Playdate.Scoreboards` | `playdate->scoreboards` | online leaderboards |
| `Playdate.Network` | `playdate->network` | wifi, `HTTPConnection`, `TCPConnection` |

## Requirements

- The [Playdate SDK](https://play.date/dev/) (3.1.1 or later). The SDK is
  not vendored into this repository.
- Swift 6.4 tools or later.

### One-time SDK setup

The `CPlaydate` target resolves `pd_api.h` through a `playdate` pkg-config
module, so the package works as a normal SwiftPM dependency without unsafe
build flags. Generate the pkg-config file once per machine:

```sh
Scripts/install-pkgconfig.sh
```

The script locates the SDK via `PLAYDATE_SDK_PATH` (default
`~/Developer/PlaydateSDK`) and writes `playdate.pc` into a directory SwiftPM
searches by default (`/usr/local/lib/pkgconfig`). Pass a custom destination
as an argument if you prefer another location on your `PKG_CONFIG_PATH`.

If Xcode had the package open before you ran the script, make it re-read the
manifest (File ▸ Packages ▸ Reset Package Caches) — Xcode caches package
resolution and won't notice the new `.pc` file on its own.

## Adding the dependency

```swift
// Package.swift of your game
dependencies: [
    .package(url: "https://github.com/<you>/play-date.git", from: "0.1.0"),
    // …or, while developing locally:
    // .package(path: "../play-date"),
],
targets: [
    .target(
        name: "MyGame",
        dependencies: [.product(name: "PlayDate", package: "play-date")]
    ),
]
```

## Getting started

A Playdate game has a single C entry point, `eventHandler`. Export it with
`@_cdecl`, initialize the binding on the first event, and install an update
callback:

```swift
import CPlaydate
import PlayDate

@_cdecl("eventHandler")
func eventHandler(pointer: UnsafeMutableRawPointer,
                  event: PDSystemEvent,
                  argument: UInt32) -> Int32 {
    switch Playdate.SystemEvent(event: event, argument: argument) {
    case .initialize:
        Playdate.initialize(with: pointer)   // must happen before anything else
        Game.shared.start()
    case .pause:
        Game.shared.pause()
    default:
        break
    }
    return 0
}

final class Game {
    nonisolated(unsafe) static let shared = Game()

    var player = Playdate.Sprite()

    func start() {
        Playdate.Display.setRefreshRate(50)

        Playdate.System.setUpdateCallback {
            self.update()
            return true   // true = redraw the display this frame
        }
    }

    func update() {
        let (_, pushed, _) = Playdate.System.buttonState
        if pushed.contains(.a) {
            Playdate.System.log("A pressed at \(Playdate.System.currentTimeMilliseconds)ms")
        }

        Playdate.Sprite.updateAndDrawAll()
        Playdate.System.drawFPS()
    }
}
```

`Playdate.initialize(with:)` stores the API pointer once; every wrapper in
the module uses it from then on. Calling any wrapper before `initialize` is
a programmer error and will crash.

## Tour of the API

### System: input, time, menu

```swift
// Buttons are an OptionSet: current (held), pushed and released this frame.
let (current, pushed, released) = Playdate.System.buttonState
if current.contains([.b, .down]) { /* charge shot */ }

// Crank.
if !Playdate.System.isCrankDocked {
    aim(degrees: Playdate.System.crankAngle)
    spin(by: Playdate.System.crankChange)
}

// Accelerometer is a peripheral you enable first.
Playdate.System.setPeripheralsEnabled(.accelerometer)
let (x, y, z) = Playdate.System.accelerometer

// System menu items take closures; the binding keeps them alive until removed.
Playdate.System.addCheckmarkMenuItem(title: "music", isChecked: true) { item in
    Audio.musicEnabled = item.isChecked
}
Playdate.System.addOptionsMenuItem(title: "mode", options: ["easy", "hard"]) { item in
    Game.shared.difficulty = item.value
}

// Logging goes to the simulator console or device serial.
Playdate.System.log("spawned \(count) enemies")
Playdate.System.error("unrecoverable")   // stops execution
```

### Graphics: drawing, bitmaps, fonts

Fallible loads (`Bitmap(path:)`, `Font(path:)`, …) throw `Playdate.Error`,
which carries the message produced by the OS:

```swift
let font = try Playdate.Graphics.Font(path: "fonts/Asheville-Sans-14-Bold.pft")
Playdate.Graphics.setFont(font)

Playdate.Graphics.clear(color: .white)
Playdate.Graphics.fillRect(x: 0, y: 0, width: 400, height: 32, color: .black)
Playdate.Graphics.drawText("Hëllo, Playdate", x: 8, y: 8)

// Colors are solid or 8×8 patterns.
let checker = Playdate.Graphics.Pattern(rows: (0xAA, 0x55, 0xAA, 0x55,
                                               0xAA, 0x55, 0xAA, 0x55))
Playdate.Graphics.fillEllipse(x: 100, y: 100, width: 64, height: 64,
                              color: .pattern(checker))

// Bitmaps draw themselves; draw into one by pushing it as the context.
let logo = try Playdate.Graphics.Bitmap(path: "images/logo")
logo.draw(x: 168, y: 88)

let canvas = Playdate.Graphics.Bitmap(width: 64, height: 64)
Playdate.Graphics.pushContext(canvas)
Playdate.Graphics.drawLine(x1: 0, y1: 0, x2: 63, y2: 63, width: 2, color: .black)
Playdate.Graphics.popContext()
```

### Sprites and collisions

```swift
let ball = Playdate.Sprite()
ball.setImage(try Playdate.Graphics.Bitmap(path: "images/ball"))
ball.moveTo(x: 200, y: 120)
ball.collideRect = Playdate.Rect(x: 0, y: 0, width: 16, height: 16)
ball.setCollisionResponseFunction { _, _ in .bounce }
ball.add()   // adds to the display list; the binding keeps it alive while added

// In the update callback:
let (actual, collisions) = ball.moveWithCollisions(goalX: goalX, goalY: goalY)
for collision in collisions where collision.other.tag == Tags.brick {
    collision.other.remove()
}
```

Sprite callbacks (`setUpdateFunction`, `setDrawFunction`,
`setCollisionResponseFunction`) receive the Swift wrapper back. The C-level
sprite userdata slot is reserved by the binding for that recovery — use the
`userdata` property on `Sprite` for your own per-sprite storage instead.

### Sound

```swift
// Stream music from disk.
let music = try Playdate.Sound.FilePlayer(path: "audio/theme")
music.play(repeat: 0)   // 0 = loop forever

// Play short effects from memory.
let blip = try Playdate.Sound.SamplePlayer(path: "audio/blip")
blip.play()

// Synthesis.
let synth = Playdate.Sound.Synth(waveform: .square)
synth.setAttackTime(0.01)
synth.setReleaseTime(0.2)
synth.playMIDINote(Playdate.Sound.noteC4, velocity: 0.8, length: 0.5)

// Channels mix sources and effects.
let channel = Playdate.Sound.Channel()
channel.add()
channel.addSource(synth)
let filter = Playdate.Sound.TwoPoleFilter(kind: .lowPass)
filter.setFrequency(800)
channel.addEffect(filter)

// Anything that takes a modulator accepts any SignalValue (LFO, Envelope, …).
let wobble = Playdate.Sound.LFO(shape: .sine)
wobble.setRate(2)
synth.frequencyModulator = wobble
```

### Files and JSON

```swift
// Paths resolve against the game's Data directory and pdx per the open mode.
let save = try Playdate.File.Handle(path: "save.json", mode: .write)
try save.write(Playdate.JSON.encode(.table([
    "level": .int(3),
    "name": .string("Röck"),
])))
try save.close()

let loaded = try Playdate.JSON.decodeFile(at: "save.json")
if case .table(let entries) = loaded, case .int(let level)? = entries["level"] {
    Game.shared.level = level
}

try Playdate.File.listFiles(at: "replays") { name in
    Playdate.System.log("found \(name)")
}
```

### Network

Network access requires user permission per server:

```swift
let reply = Playdate.Network.HTTPConnection.requestAccess(
    server: "example.com", purpose: "Fetching daily puzzles") { allowed in
    guard allowed else { return }
    Puzzles.fetch()
}

func fetch() {
    guard let connection = Playdate.Network.HTTPConnection(server: "example.com") else { return }
    connection.setRequestCompleteCallback { connection in
        let body = try? connection.read(length: connection.bytesAvailable)
        // … keep `connection` referenced somewhere until this fires …
    }
    try? connection.get(path: "/daily.json")
}
```

### Lua interop

Lua callbacks are C function pointers with no context, so they must be
`@convention(c)` functions rather than capturing closures:

```swift
let double: Playdate.Lua.CFunction = { _ in
    Playdate.Lua.push(Playdate.Lua.intArgument(at: 1) * 2)
    return 1   // number of return values pushed
}
try Playdate.Lua.addFunction(double, name: "mylib.double")
```

## Conventions

- **Namespaces.** Everything lives under `Playdate`. Games that find that
  verbose can alias: `typealias Graphics = Playdate.Graphics`.
- **Errors.** Fallible operations use typed throws — `throws(Playdate.Error)`
  generally, `throws(Playdate.Network.NetError)` for network I/O — so `catch`
  gives you a concrete type, and no `any Error` existentials are needed.
- **Ownership.** A wrapper that *creates* a C object frees it on `deinit`;
  keep the wrapper referenced for as long as you use it. Wrappers vending
  OS-owned objects (a `Bitmap` from a `BitmapTable`, a track from a
  `Sequence`, …) don't free them — keep the owner alive instead, as
  documented on each API. Resources a C object keeps referencing (a sprite's
  image, a synth's sample, modulators, menu-item option titles) are retained
  by the wrapper automatically.
- **Callbacks.** Where the C API provides a userdata slot, closures are
  supported everywhere and delivered back with the right wrapper. A few C
  callbacks have no userdata (serial messages, headphone changes, scoreboard
  completions, `getServerTime`); those track one Swift closure at a time, as
  noted in their documentation.
- **Threading.** The Playdate runtime is single-threaded (audio callbacks
  excepted); statics in the binding are `nonisolated(unsafe)` on that basis.
  Don't call the API from other threads.

## Building for the simulator and device

This package builds as a plain Swift library, which is how you develop and
unit-test game logic on the host (`swift test` works out of the box).

Shipping a `.pdx` needs the Playdate toolchain on top:

- **Simulator** builds compile your game as a host dylib placed in the pdx.
- **Device** builds require Embedded Swift for ARM Cortex-M7
  (`-enable-experimental-feature Embedded`, triple `armv7em-none-none-eabi`).

The wrappers are written within the Embedded Swift subset for exactly this
reason: no Foundation, no reflection, no untyped throws. See Apple's
[swift-playdate-examples](https://github.com/apple/swift-playdate-examples)
for a working Makefile/toolchain setup that this library slots into.

## Layout

```
Scripts/
  install-pkgconfig.sh   One-time setup: points the "playdate" pkg-config
                         module at your SDK installation
Sources/
  CPlaydate/        System library target: module map + umbrella header
                    importing pd_api.h from the SDK, plus inline shims for
                    the variadic log/error functions
  PlayDate/         The Swift bindings, one file per subsystem
                    (Sound and Graphics are split across several files)
Tests/
  PlayDate/         Host-runnable tests for the pure value types
```

## License

MIT — see [LICENSE](LICENSE). The Playdate SDK itself is licensed separately
by Panic, Inc. and is not distributed with this package.
