#!/bin/sh
#
# Generates a pkg-config file for the Playdate SDK C API so SwiftPM can
# resolve the CPlaydate system library target.
#
# Usage:
#   Scripts/install-pkgconfig.sh [destination-directory]
#
# The SDK is located via $PLAYDATE_SDK_PATH, falling back to
# ~/Developer/PlaydateSDK. Without a destination argument, the file is
# installed into the first writable directory that SwiftPM (including
# Xcode's SwiftPM) searches by default.

set -eu

sdk_path="${PLAYDATE_SDK_PATH:-$HOME/Developer/PlaydateSDK}"

if [ ! -f "$sdk_path/C_API/pd_api.h" ]; then
    echo "error: pd_api.h not found under '$sdk_path/C_API'." >&2
    echo "Install the Playdate SDK or set PLAYDATE_SDK_PATH." >&2
    exit 1
fi

version="unknown"
if [ -f "$sdk_path/VERSION.txt" ]; then
    version="$(head -1 "$sdk_path/VERSION.txt" | tr -d '[:space:]')"
fi

destination="${1:-}"
if [ -z "$destination" ]; then
    # Locations SwiftPM (and Xcode's SwiftPM) searches without
    # PKG_CONFIG_PATH. Note: Homebrew's /opt/homebrew/lib/pkgconfig is NOT
    # searched by default.
    for candidate in /usr/local/lib/pkgconfig /usr/local/share/pkgconfig; do
        parent="$(dirname "$candidate")"
        if [ -d "$candidate" ] && [ -w "$candidate" ]; then
            destination="$candidate"
            break
        elif [ -d "$parent" ] && [ -w "$parent" ]; then
            destination="$candidate"
            break
        fi
    done
fi

if [ -z "$destination" ]; then
    echo "error: no writable pkg-config directory found." >&2
    echo "Re-run with a destination directory, e.g.:" >&2
    echo "  sudo Scripts/install-pkgconfig.sh /usr/local/lib/pkgconfig" >&2
    echo "or pick your own directory and add it to PKG_CONFIG_PATH." >&2
    exit 1
fi

mkdir -p "$destination"
cat > "$destination/playdate.pc" <<EOF
prefix=$sdk_path

Name: playdate
Description: Playdate SDK C API headers
Version: $version
Cflags: -I\${prefix}/C_API
EOF

echo "Wrote $destination/playdate.pc (SDK $version at $sdk_path)"

case "$destination" in
    /usr/local/lib/pkgconfig|/usr/local/share/pkgconfig|/usr/lib/pkgconfig|/usr/share/pkgconfig)
        ;;
    *)
        echo "note: '$destination' is not on SwiftPM's default search path;"
        echo "      export PKG_CONFIG_PATH=\"$destination\" when building."
        ;;
esac
