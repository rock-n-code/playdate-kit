# ``PlaydateKit``

Swift bindings to the Playdate C API.

## Overview

The Playdate C API is delivered as a `PlaydateAPI*` struct of function
pointers that the firmware hands to your game at launch. This module wraps
that surface in idiomatic Swift: top-level namespaces per subsystem, wrapper
types with ownership semantics, closures instead of function-pointer/userdata
pairs, `OptionSet`s and `enum`s instead of raw constants, and typed `throws`
for fallible calls.

Call ``Playdate/initialize(with:)`` from your game's `eventHandler` before
using anything else — see <doc:GettingStarted>.

The bindings are written within the Embedded Swift subset, so the same code
compiles for the Playdate Simulator and for the device
(`armv7em-none-none-eabi`).

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
