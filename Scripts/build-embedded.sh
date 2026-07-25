#!/bin/sh
#
# Cross-compiles the PlayDate target for Playdate hardware (Embedded Swift,
# ARM Cortex-M7) as a compile-only check that the bindings stay within the
# Embedded Swift subset. Linking is left to game projects.
#
# Requirements:
# - A Swift toolchain with the embedded stdlib for armv7em-none-none-eabi
#   (a swift.org development snapshot; Xcode's toolchain does not ship it).
#   Override the binary with SWIFT_BIN, otherwise `swift` from PATH is used.
# - Arm GNU toolchain (arm-none-eabi) C headers, because pd_api.h includes
#   libc headers that bare-metal builds resolve against newlib. Override the
#   directory with ARM_NONE_EABI_INCLUDE, otherwise common install locations
#   are searched.
# - The "playdate" pkg-config module (Scripts/install-pkgconfig.sh).

set -eu

swift_bin="${SWIFT_BIN:-swift}"

include_dir="${ARM_NONE_EABI_INCLUDE:-}"
if [ -z "$include_dir" ]; then
    for candidate in \
        /usr/local/playdate/gcc-arm-none-eabi-*/arm-none-eabi/include \
        /Applications/ArmGNUToolchain/*/arm-none-eabi/arm-none-eabi/include \
        /usr/lib/arm-none-eabi/include \
        /usr/include/newlib; do
        if [ -f "$candidate/stdlib.h" ]; then
            include_dir="$candidate"
            break
        fi
    done
fi

if [ -z "$include_dir" ] || [ ! -f "$include_dir/stdlib.h" ]; then
    echo "error: arm-none-eabi C headers not found." >&2
    echo "Install the Arm GNU toolchain or set ARM_NONE_EABI_INCLUDE." >&2
    exit 1
fi

echo "Using swift: $swift_bin ($($swift_bin --version 2>/dev/null | head -1))"
echo "Using arm-none-eabi headers: $include_dir"

# --build-system native stops after compilation; the default build system
# also tries to merge objects with the host linker, which cannot process
# bare-metal ELF objects.
exec "$swift_bin" build \
    --build-system native \
    --target PlayDate \
    --triple armv7em-none-none-eabi \
    -Xswiftc -enable-experimental-feature -Xswiftc Embedded \
    -Xswiftc -wmo \
    -Xcc -I"$include_dir" \
    -Xcc -mcpu=cortex-m7 \
    -Xcc -mfloat-abi=hard \
    -Xcc -mfpu=fpv5-sp-d16 \
    -Xcc -fshort-enums
