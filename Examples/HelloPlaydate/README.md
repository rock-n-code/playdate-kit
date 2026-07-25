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

The Makefile cross-compiles the game with Embedded Swift and packages a
`HelloPlaydate.pdx` containing both the device binary and the simulator
dylib. It needs:

- the Playdate SDK (`PLAYDATE_SDK_PATH`, or the path in `~/.Playdate/config`),
- the Arm GNU toolchain (`arm-none-eabi-gcc`) on `PATH`,
- a swift.org development-snapshot toolchain (Xcode's toolchain does not
  ship the Embedded Swift stdlib for the device target). A toolchain
  installed at `~/Library/Developer/Toolchains` is picked up automatically;
  otherwise pass `TOOLCHAINS=<bundle id>`.

```sh
make
```

Swift code is compiled with `-Osize` by default; use `make SWIFT_OPT=-O` to
favor speed over size. Sideload the pdx from the Playdate Simulator
(Device > Upload Game to Device) or with the SDK's `pdutil`.
