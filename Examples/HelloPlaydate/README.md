# Hello Playdate

A minimal game built on the `play-date` bindings: a bouncing box, a
crank-aimed needle, button handling, a system menu item, and an FPS counter.

## Build and run (Playdate Simulator)

With the Playdate SDK installed (and the one-time
`Scripts/install-pkgconfig.sh` setup from the repository root done):

```sh
./build.sh
open -a "$HOME/Developer/PlaydateSDK/bin/Playdate Simulator.app" HelloPlaydate.pdx
```

The script compiles the game as a dylib, places it in `Source/` next to
`pdxinfo`, and runs the SDK's `pdc` to produce `HelloPlaydate.pdx`.

## Device builds

Running on hardware requires the Embedded Swift + ARM toolchain pipeline
(see the repository README and Apple's swift-playdate-examples for the
Makefile setup). This example covers the simulator workflow only.
