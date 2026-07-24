#!/bin/sh
#
# Builds HelloPlaydate.pdx for the Playdate Simulator: compiles the game as
# a dylib, places it in the pdc source folder, and runs the SDK's pdc.
#
# Device builds need the Embedded Swift + ARM toolchain setup described in
# the repository README; this script covers the simulator only.

set -eu
cd "$(dirname "$0")"

sdk_path="${PLAYDATE_SDK_PATH:-$HOME/Developer/PlaydateSDK}"

swift build -c release
bin_path="$(swift build -c release --show-bin-path)"
cp "$bin_path/libpdex.dylib" Source/pdex.dylib

"$sdk_path/bin/pdc" Source HelloPlaydate.pdx

echo "Built HelloPlaydate.pdx — run it with:"
echo "  open -a \"$sdk_path/bin/Playdate Simulator.app\" HelloPlaydate.pdx"
