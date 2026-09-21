// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SyzygyServices",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SyzygyServices",
            targets: ["SyzygyServices"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Syzygy-Hub/syzygy-foundation-ios", from: "1.2.0")
    ],
    targets: [
        .target(
            name: "SyzygyServices",
            dependencies: [
                .product(name: "SyzygyFoundation", package: "syzygy-foundation-ios")
            ],
            path: "Sources/SyzygyServices"
        ),
        .testTarget(
            name: "SyzygyServicesTests",
            dependencies: ["SyzygyServices"],
            path: "Tests/SyzygyServicesTests"
        )
    ]
)
