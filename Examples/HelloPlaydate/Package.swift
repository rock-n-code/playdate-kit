// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "HelloPlaydate",
    products: [
        // The Playdate Simulator loads the game as pdex.dylib.
        .library(name: "pdex", type: .dynamic, targets: ["HelloPlaydate"]),
    ],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .target(
            name: "HelloPlaydate",
            dependencies: [.product(name: "PlayDate", package: "play-date")]
        ),
    ]
)
