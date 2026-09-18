# Getting Started

Bootstrap the bindings from your game's entry point and drive a frame loop.

## Overview

The firmware calls a game's single C entry point, `eventHandler`, with a
`PlaydateAPI*` and an event code. Export it with `@c`, call
``Playdate/initialize(with:)`` on the first event, and install an update
callback:

```swift
import CPlaydate
import PlaydateKit

@c(eventHandler)
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

- **Initialization.** Calling a wrapper before
  ``Playdate/initialize(with:)`` crashes.
- **Errors.** Typed throws: ``PlaydateError`` in general,
  ``Network/NetError`` for network I/O.
- **Ownership.** A wrapper that creates a C object frees it on `deinit`;
  keep the wrapper referenced while you use it. Objects vended by the OS
  are not freed by their wrapper; keep the owner alive instead.
- **Buffers.** Audio callbacks, I/O, the framebuffer, and bitmap pixels use
  `Span`/`MutableSpan`, valid only for the duration of the call.
- **Threading.** The Playdate runtime is single-threaded, except audio
  callbacks. Do not call the API from other threads.
