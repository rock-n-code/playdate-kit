# PlaydateKit

[![CI](https://github.com/<you>/playdate-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/<you>/playdate-kit/actions/workflows/ci.yml)

Swift bindings to the [Playdate](https://play.date) C API.

The Playdate C API is delivered as a `PlaydateAPI*` struct of function pointers that the firmware hands to your game at launch. This package wraps that surface in idiomatic Swift: namespaced APIs, wrapper types with ownership semantics, closures instead of function-pointer/userdata pairs, `OptionSet`s and `enum`s instead of raw constants, and typed `throws` for fallible calls.

All ten C subsystems are covered:

| Namespace | Wraps | Highlights |
|---|---|---|
| `System` | `playdate->system` | input, time, menu items, logging |
| `Display` | `playdate->display` | refresh rate, scale, mosaic, flip |
| `Graphics` | `playdate->graphics` | drawing, `Bitmap`, `Font`, `TileMap`, video |
| `Sprite` | `playdate->sprite` | display list, collisions, custom draw |
| `Sound` | `playdate->sound` | players, synths, sequences, effects |
| `File` | `playdate->file` | `Handle`, directory operations |
| `JSON` | `playdate->json` | `Value` tree decode/encode |
| `Lua` | `playdate->lua` | C functions, classes, stack access |
| `Scoreboards` | `playdate->scoreboards` | online leaderboards |
| `Network` | `playdate->network` | wifi, `HTTPConnection`, `TCPConnection` |

## Requirements

- The [Playdate SDK](https://play.date/dev/) (3.1.1 or later). The SDK is not vendored into this repository.
- Swift 6.4 tools or later.

Device builds additionally need:

- A [swift.org development snapshot toolchain](https://www.swift.org/install/macos/) — Xcode's toolchain does not ship the Embedded Swift stdlib for the device target (`armv7em-none-none-eabi`).
- The [Arm GNU toolchain](https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads) (`arm-none-eabi-gcc`) on your `PATH`, which the Playdate SDK's build support uses to compile and link the device binary.

### One-time SDK setup

The `CPlaydate` target resolves `pd_api.h` through a `playdate` pkg-config module, so the package works as a normal SwiftPM dependency without unsafe build flags. Generate the pkg-config file once per machine:

```sh
Scripts/install-pkgconfig.sh
```

The script locates the SDK via `PLAYDATE_SDK_PATH` (default `~/Developer/PlaydateSDK`) and writes `playdate.pc` into a directory SwiftPM searches by default (`/usr/local/lib/pkgconfig`). Pass a custom destination as an argument if you prefer another location on your `PKG_CONFIG_PATH`.

If Xcode had the package open before you ran the script, make it re-read the manifest (File ▸ Packages ▸ Reset Package Caches) — Xcode caches package resolution and won't notice the new `.pc` file on its own.

## Adding the dependency

```swift
// Package.swift of your game
dependencies: [
    .package(url: "https://github.com/<you>/playdate-kit.git", from: "0.1.0"),
    // …or, while developing locally:
    // .package(path: "../playdate-kit"),
],
targets: [
    .target(
        name: "MyGame",
        dependencies: [.product(name: "PlaydateKit", package: "playdate-kit")]
    ),
]
```

## Getting started

A Playdate game has a single C entry point, `eventHandler`. Export it with `@_cdecl`, initialize the binding on the first event, and install an update callback:

```swift
import CPlaydate
import PlaydateKit

@_cdecl("eventHandler")
func eventHandler(
    pointer: UnsafeMutableRawPointer,
    event: PDSystemEvent,
    argument: UInt32
) -> Int32 {
    switch SystemEvent(event: event, argument: argument) {
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

    var player = Sprite()

    func start() {
        Display.setRefreshRate(50)

        System.setUpdateCallback {
            self.update()
            return true   // true = redraw the display this frame
        }
    }

    func update() {
        let (_, pushed, _) = System.buttonState
        if pushed.contains(.a) {
            System.log("A pressed at \(System.currentTimeMilliseconds)ms")
        }

        Sprite.updateAndDrawAll()
        System.drawFPS()
    }
}
```

`Playdate.initialize(with:)` stores the API pointer once; every wrapper in the module uses it from then on. Calling any wrapper before `initialize` is a programmer error and will crash.

## Tour of the API

### System: input, time, menu

```swift
// Buttons are an OptionSet: current (held), pushed and released this frame.
let (current, pushed, released) = System.buttonState
if current.contains([.b, .down]) { /* charge shot */ }

// Crank.
if !System.isCrankDocked {
    aim(degrees: System.crankAngle)
    spin(by: System.crankChange)
}

// Accelerometer is a peripheral you enable first.
System.setPeripheralsEnabled(.accelerometer)
let (x, y, z) = System.accelerometer

// System menu items take closures; the binding keeps them alive until removed.
System.addCheckmarkMenuItem(title: "music", isChecked: true) { item in
    Audio.musicEnabled = item.isChecked
}
System.addOptionsMenuItem(title: "mode", options: ["easy", "hard"]) { item in
    Game.shared.difficulty = item.value
}

// Logging goes to the simulator console or device serial.
System.log("spawned \(count) enemies")
System.error("unrecoverable")   // stops execution
```

### Graphics: drawing, bitmaps, fonts

Fallible loads (`Bitmap(path:)`, `Font(path:)`, …) throw `PlaydateError`,
which carries the message produced by the OS:

```swift
let font = try Graphics.Font(path: "fonts/Asheville-Sans-14-Bold.pft")
Graphics.setFont(font)

Graphics.clear(color: .white)
Graphics.fillRect(x: 0, y: 0, width: 400, height: 32, color: .black)
Graphics.drawText("Hëllo, Playdate", x: 8, y: 8)

// Colors are solid or 8×8 patterns.
let checker = Graphics.Pattern(rows: (0xAA, 0x55, 0xAA, 0x55,
                                      0xAA, 0x55, 0xAA, 0x55))
Graphics.fillEllipse(x: 100, y: 100, width: 64, height: 64,
                     color: .pattern(checker))

// Bitmaps draw themselves; draw into one by pushing it as the context.
let logo = try Graphics.Bitmap(path: "images/logo")
logo.draw(x: 168, y: 88)

let canvas = Graphics.Bitmap(width: 64, height: 64)
Graphics.pushContext(canvas)
Graphics.drawLine(x1: 0, y1: 0, x2: 63, y2: 63, width: 2, color: .black)
Graphics.popContext()
```

### Sprites and collisions

```swift
let ball = Sprite()
ball.setImage(try Graphics.Bitmap(path: "images/ball"))
ball.moveTo(x: 200, y: 120)
ball.collideRect = Rect(x: 0, y: 0, width: 16, height: 16)
ball.setCollisionResponseFunction { _, _ in .bounce }
ball.add()   // adds to the display list; the binding keeps it alive while added

// In the update callback:
let (actual, collisions) = ball.moveWithCollisions(goalX: goalX, goalY: goalY)
for collision in collisions where collision.other.tag == Tags.brick {
    collision.other.remove()
}

// Every collision/query API also has a visitor form that iterates the
// results in place instead of building an array — useful in hot loops:
ball.moveWithCollisions(goalX: goalX, goalY: goalY) { collision in
    if collision.other.tag == Tags.brick { collision.other.remove() }
}
```

Sprite callbacks (`setUpdateFunction`, `setDrawFunction`, `setCollisionResponseFunction`) receive the Swift wrapper back. The C-level sprite userdata slot is reserved by the binding for that recovery — use the `userdata` property on `Sprite` for your own per-sprite storage instead.

### Sound

```swift
// Stream music from disk.
let music = try Sound.FilePlayer(path: "audio/theme")
music.play(repeat: 0)   // 0 = loop forever

// Play short effects from memory.
let blip = try Sound.SamplePlayer(path: "audio/blip")
blip.play()

// Synthesis.
let synth = Sound.Synth(waveform: .square)
synth.setAttackTime(0.01)
synth.setReleaseTime(0.2)
synth.playMIDINote(Sound.noteC4, velocity: 0.8, length: 0.5)

// Channels mix sources and effects.
let channel = Sound.Channel()
channel.add()
channel.addSource(synth)
let filter = Sound.TwoPoleFilter(kind: .lowPass)
filter.setFrequency(800)
channel.addEffect(filter)

// Anything that takes a modulator accepts any SignalValue (LFO, Envelope, …).
let wobble = Sound.LFO(shape: .sine)
wobble.setRate(2)
synth.frequencyModulator = wobble
```

### Files and JSON

```swift
// Paths resolve against the game's Data directory and pdx per the open mode.
let save = try File.Handle(path: "save.json", mode: .write)
try save.write(JSON.encode(.table([
    "level": .int(3),
    "name": .string("Röck"),
])))
try save.close()

let loaded = try JSON.decodeFile(at: "save.json")
if case .table(let entries) = loaded, case .int(let level)? = entries["level"] {
    Game.shared.level = level
}

try File.listFiles(at: "replays") { name in
    System.log("found \(name)")
}
```

### Network

Network access requires user permission per server:

```swift
let reply = Network.HTTPConnection.requestAccess(
    server: "example.com", purpose: "Fetching daily puzzles") { allowed in
    guard allowed else { return }
    Puzzles.fetch()
}

func fetch() {
    guard let connection = Network.HTTPConnection(server: "example.com") else { return }
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
let double: Lua.CFunction = { _ in
    Lua.push(Lua.intArgument(at: 1) * 2)
    return 1   // number of return values pushed
}
try Lua.addFunction(double, name: "mylib.double")
```

## Conventions

- **Namespaces.** The subsystem namespaces (`System`, `Graphics`, `Sound`, …) live at the top level of the module; only the raw C API bootstrap stays under `Playdate` (`Playdate.initialize(with:)`, `Playdate.api`). On a name collision with another module, qualify with the module name: `PlaydateKit.System`.
- **Errors.** Fallible operations use typed throws — `throws(PlaydateError)` generally, `throws(Network.NetError)` for network I/O — so `catch` gives you a concrete type, and no `any Error` existentials are needed.
- **Ownership.** A wrapper that *creates* a C object frees it on `deinit`; keep the wrapper referenced for as long as you use it. Wrappers vending OS-owned objects (a `Bitmap` from a `BitmapTable`, a track from a `Sequence`, …) don't free them — keep the owner alive instead, as documented on each API. Resources a C object keeps referencing (a sprite's image, a synth's sample, modulators, menu-item option titles) are retained by the wrapper automatically.
- **Callbacks.** Where the C API provides a userdata slot, closures are supported everywhere and delivered back with the right wrapper. A few C callbacks have no userdata (serial messages, headphone changes, scoreboard
  completions, `getServerTime`); those track one Swift closure at a time, as noted in their documentation.
- **Threading.** The Playdate runtime is single-threaded (audio callbacks excepted); statics in the binding are `nonisolated(unsafe)` on that basis. Don't call the API from other threads.

## Building for the simulator and device

This package builds as a plain Swift library, which is how you develop and unit-test game logic on the host (`swift test` works out of the box).

Shipping a `.pdx` needs the Playdate toolchain on top:

- **Simulator** builds compile your game as a host dylib placed in the pdx (`Examples/HelloPlaydate/build.sh` shows the SwiftPM-based flow).
- **Device** builds cross-compile with Embedded Swift for ARM Cortex-M7 (`-enable-experimental-feature Embedded`, triple `armv7em-none-none-eabi`, `-fshort-enums` to match the firmware ABI) and link through the SDK's own make infrastructure.

[`Examples/swift.mk`](Examples/swift.mk) packages the device pipeline: it locates the SDK and a Swift snapshot toolchain, compiles the `PlaydateKit` wrapper as a module-aliased Embedded Swift module, and hooks the game objects into the SDK's `common.mk`. A game needs only a short Makefile on top — [`Examples/HelloPlaydate/Makefile`](Examples/HelloPlaydate/Makefile) is the template, and `make` in that directory produces a `.pdx` containing both the device binary and the simulator dylib. Swift code is compiled `-Osize` by default (measured ~15% smaller than `-O` on the example); override with `make SWIFT_OPT=-O`. The setup follows Apple's [swift-playdate-examples](https://github.com/apple/swift-playdate-examples), adapted to this package.

The wrappers are written within the Embedded Swift subset for exactly this reason: no Foundation, no reflection, no untyped throws. That claim is enforced, not aspirational: `Scripts/build-embedded.sh` cross-compiles the whole module for `armv7em-none-none-eabi` with Embedded Swift enabled and the device's `-fshort-enums` ABI, and CI runs it on every push. Running it locally needs the same snapshot toolchain and Arm GNU toolchain headers:

```sh
SWIFT_BIN=~/Library/Developer/Toolchains/swift-DEVELOPMENT-SNAPSHOT-<date>.xctoolchain/usr/bin/swift \
    Scripts/build-embedded.sh
```

## Make targets

A root Makefile fronts the development lifecycle; a bare `make` (or `make help`) lists the targets. `build`, `test`, `docs`, and `consumer-test` need only Xcode's toolchain (after the one-time `make setup`); `embedded` and the example targets additionally need the device toolchains above — `embedded` picks up a snapshot toolchain installed at `~/Library/Developer/Toolchains` automatically, or takes `SWIFT_BIN=<path to swift>`.

| Target | Effect |
|---|---|
| `make setup` | One-time: point the `playdate` pkg-config module at the SDK |
| `make build` / `make test` | Build the bindings for the host / run the unit tests |
| `make outdated` / `make upgrade` | Show / apply updates to the SwiftPM dependencies |
| `make embedded` | Compile-only device check (Embedded Swift, `armv7em-none-none-eabi`) |
| `make consumer-test` | Build and run a scratch package depending on playdate-kit |
| `make check` | Everything CI runs: build, test, embedded, consumer-test |
| `make docs` / `make docs-preview` | Generate / preview the DocC documentation |
| `make example` / `make example-run` | Build the HelloPlaydate example / open it in the Playdate Simulator |
| `make clean` | Remove build products of the package and the example |

## Example

[`Examples/HelloPlaydate`](Examples/HelloPlaydate) is a complete minimal game — bouncing box, crank needle, button handling, a system menu item — that builds into a runnable `.pdx`:

```sh
cd Examples/HelloPlaydate

# Simulator only (plain SwiftPM, no extra toolchains):
./build.sh
open -a "$HOME/Developer/PlaydateSDK/bin/Playdate Simulator.app" HelloPlaydate.pdx

# Device + simulator (snapshot toolchain and arm-none-eabi-gcc required):
make
```

Sideload the device build from the Playdate Simulator (Device ▸ Upload Game to Device) or with the SDK's `pdutil`.

## Documentation

The API reference is a DocC catalog. Generate it locally with:

```sh
swift package generate-documentation --target PlaydateKit
```

or browse it with Xcode's documentation viewer (Product ▸ Build Documentation). Pushes to `main` publish the rendered docs to GitHub Pages via `.github/workflows/docs.yml` (enable Pages ▸ Source: GitHub Actions in the repository settings once).

## Layout

```
Examples/
  swift.mk          Shared make rules for device builds: toolchain/SDK
                    discovery and Embedded Swift compile flags
  HelloPlaydate/    Minimal game buildable into a .pdx for the simulator
                    (build.sh) or simulator + device (make)
Scripts/
  install-pkgconfig.sh   One-time setup: points the "playdate" pkg-config
                         module at your SDK installation
  build-embedded.sh      Compile-only device check: Embedded Swift for
                         armv7em-none-none-eabi with the device ABI (CI)
  consumer-test.sh       Builds a scratch package depending on playdate-kit
                         to prove settings propagate to consumers (CI)
Sources/
  CPlaydate/        System library target: module map + umbrella header
                    importing pd_api.h from the SDK, plus inline shims for
                    the variadic log/error functions
  PlaydateKit/      The Swift bindings, one file per subsystem
                    (Sound and Graphics are split across several files),
                    plus the PlaydateKit.docc documentation catalog
Tests/
  PlaydateKit/      Host-runnable tests for the pure value types
```

## License

MIT — see [LICENSE](LICENSE). The Playdate SDK itself is licensed separately by Panic, Inc. and is not distributed with this package.
