#!/bin/sh
#
# Verifies the package works as a SwiftPM dependency: generates a scratch
# executable package that depends on play-date, imports both modules, and
# runs it. This guards the pkg-config setup — target settings that don't
# propagate to consumers (or manifest validation failures) surface here,
# not on this package's own build.

set -eu

package_dir="$(cd "$(dirname "$0")/.." && pwd)"
scratch_dir="$(mktemp -d)"
trap 'rm -rf "$scratch_dir"' EXIT

mkdir -p "$scratch_dir/Sources/consumer"

cat > "$scratch_dir/Package.swift" <<EOF
// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "consumer",
    dependencies: [
        .package(path: "$package_dir"),
    ],
    targets: [
        .executableTarget(
            name: "consumer",
            dependencies: [.product(name: "PlayDate", package: "play-date")]
        ),
    ]
)
EOF

cat > "$scratch_dir/Sources/consumer/main.swift" <<'EOF'
import CPlaydate
import PlayDate

// Touch a type from each module to prove both import and link.
let event = SystemEvent(event: kEventInit, argument: 0)
let buttons: System.Buttons = [.a, .up]
print(event != nil && buttons.contains(.a) ? "ok" : "broken")
EOF

cd "$scratch_dir"
output="$(swift run 2>&1 | tail -1)"
echo "consumer output: $output"
[ "$output" = "ok" ]
