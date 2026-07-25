// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "play-date",
    products: [
        .library(
            name: "PlayDate",
            targets: ["PlayDate"]
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
            name: "PlayDate",
            dependencies: ["CPlaydate"],
            path: "Sources/PlayDate",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
        .testTarget(
            name: "PlayDateTests",
            dependencies: ["PlayDate"],
            path: "Tests/PlayDate",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
    ]
)
