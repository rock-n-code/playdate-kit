# ``PlaydateKit``

Swift bindings to the Playdate C API.

## Overview

The firmware hands your game a `PlaydateAPI*`: a struct of function
pointers. This module wraps it with per-subsystem namespaces, wrapper types
that own their C objects, closures instead of function-pointer/userdata
pairs, `OptionSet`s and `enum`s instead of raw constants, and typed `throws`.

Call ``Playdate/initialize(with:)`` from your game's `eventHandler` before
anything else; see <doc:GettingStarted>.

The module uses only the Embedded Swift subset, so the same code compiles
for the Playdate Simulator and the device (`armv7em-none-none-eabi`).

## Topics

### Essentials

- <doc:GettingStarted>
- ``Playdate``
- ``SystemEvent``
- ``PlaydateError``

### System and display

- ``System``
- ``Display``

### Drawing

- ``Graphics``
- ``Rect``

### Sprites

- ``Sprite``

### Audio

- ``Sound``

### Storage

- ``File``
- ``JSON``

### Connectivity

- ``Network``
- ``Scoreboards``
- ``AccessReply``

### Lua interop

- ``Lua``
