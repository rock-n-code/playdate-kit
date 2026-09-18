// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "HelloPlaydate",
    products: [
        // The Playdate Simulator loads the game as pdex.dylib.
        .library(
            name: "pdex", 
            type: .dynamic, 
            targets: ["HelloPlaydate"]
        ),
    ],
    dependencies: [
        // The explicit name overrides the identity a path dependency
        // otherwise derives from the checkout directory's name.
        .package(
            name: "playdate-kit",
            path: "../.."
        ),
    ],
    targets: [
        .target(
            name: "HelloPlaydate",
            dependencies: [
                .product(
                    name: "PlaydateKit",
                    package: "playdate-kit"
                )
            ]
        ),
    ]
)
