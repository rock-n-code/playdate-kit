// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "playdate-kit",
    products: [
        .library(
            name: "PlaydateKit",
            targets: ["PlaydateKit"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-docc-plugin",
            from: "1.4.0"
        ),
    ],
    targets: [
        // The Playdate C API headers, resolved through the "playdate"
        // pkg-config module. Run Scripts/install-pkgconfig.sh once to point
        // it at your Playdate SDK installation.
        .systemLibrary(
            name: "CPlaydate",
            path: "Sources/CPlaydate",
            pkgConfig: "playdate"
        ),
        .target(
            name: "PlaydateKit",
            dependencies: ["CPlaydate"],
            path: "Sources/PlaydateKit",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
        .testTarget(
            name: "PlaydateKitTests",
            dependencies: ["PlaydateKit"],
            path: "Tests/PlaydateKit",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
    ]
)
