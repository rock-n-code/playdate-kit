#!/bin/sh
#
# Cross-compiles the PlaydateKit target for Playdate hardware (Embedded Swift,
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
# - The Playdate SDK, located via $PLAYDATE_SDK_PATH (default
#   ~/Developer/PlaydateSDK), for pd_api.h.
#
# The module is compiled with swiftc directly rather than `swift build`:
# SwiftPM's default build system links the target's objects with Darwin
# linker flags even for bare-metal ELF targets, which neither ld64 nor
# ld.lld accept, and the native build system that stopped after compiling
# is deprecated.

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

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
swiftc_bin="$(dirname "$(command -v "$swift_bin")")/swiftc"
sdk_path="${PLAYDATE_SDK_PATH:-$HOME/Developer/PlaydateSDK}"
output_dir="$repo_root/.build/embedded"

if [ ! -f "$sdk_path/C_API/pd_api.h" ]; then
    echo "error: pd_api.h not found under '$sdk_path/C_API'." >&2
    echo "Install the Playdate SDK or set PLAYDATE_SDK_PATH." >&2
    exit 1
fi

echo "Using swiftc: $swiftc_bin ($("$swiftc_bin" --version 2>/dev/null | head -1))"
echo "Using arm-none-eabi headers: $include_dir"
echo "Using Playdate SDK: $sdk_path"

mkdir -p "$output_dir"

# The upcoming features mirror the target's swiftSettings in Package.swift.
find "$repo_root/Sources/PlaydateKit" -name '*.swift' -exec "$swiftc_bin" \
    -module-name PlaydateKit \
    -parse-as-library \
    -swift-version 6 \
    -enable-upcoming-feature ExistentialAny \
    -enable-upcoming-feature InternalImportsByDefault \
    -enable-upcoming-feature MemberImportVisibility \
    -target armv7em-none-none-eabi \
    -enable-experimental-feature Embedded \
    -wmo \
    -Osize \
    -I "$repo_root/Sources/CPlaydate" \
    -Xcc -I"$sdk_path/C_API" \
    -Xcc -I"$include_dir" \
    -Xcc -mcpu=cortex-m7 \
    -Xcc -mfloat-abi=hard \
    -Xcc -mfpu=fpv5-sp-d16 \
    -Xcc -fshort-enums \
    -module-cache-path "$output_dir/module-cache" \
    -emit-module -emit-module-path "$output_dir/PlaydateKit.swiftmodule" \
    -c -o "$output_dir/PlaydateKit.o" \
    {} +

echo "Compiled $output_dir/PlaydateKit.o"
