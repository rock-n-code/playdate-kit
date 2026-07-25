# Getting Started

Bootstrap the bindings from your game's entry point and drive a frame loop.

## Overview

A Playdate game has a single C entry point, `eventHandler`, which the
firmware calls with a `PlaydateAPI*` and an event code. Export it with
`@_cdecl`, call ``Playdate/initialize(with:)`` on the first event, and
install an update callback:

```swift
import CPlaydate
import PlaydateKit

@_cdecl("eventHandler")
func eventHandler(
    pointer: UnsafeMutableRawPointer,
    event: PDSystemEvent,
    argument: UInt32
) -> Int32 {
    if case .initialize = SystemEvent(event: event, argument: argument) {
        Playdate.initialize(with: pointer)   // must happen before anything else
        Game.shared.start()
    }

    return 0
}

final class Game {
    nonisolated(unsafe) static let shared = Game()

    func start() {
        Display.refreshRate = 50

        System.setUpdateCallback {
            self.update()
            return true   // true = redraw the display this frame
        }
    }

    func update() {
        let (_, pushed, _) = System.buttonState
        if pushed.contains(.a) {
            System.log("A pressed")
        }

        Graphics.clear(color: .white)
        Graphics.drawText("Hello, Playdate", x: 8, y: 8)
        System.drawFPS()
    }
}
```

## Conventions to know

- **Initialization.** Calling any wrapper before
  ``Playdate/initialize(with:)`` is a programmer error and will crash.
- **Errors.** Fallible operations use typed throws — ``PlaydateError``
  generally, ``Network/NetError`` for network I/O.
- **Ownership.** A wrapper that creates a C object frees it on `deinit`;
  keep the wrapper referenced for as long as you use it. Wrappers vending
  OS-owned objects don't free them — keep the owner alive instead, as
  documented on each API.
- **Threading.** The Playdate runtime is single-threaded; don't call the
  API from other threads.
