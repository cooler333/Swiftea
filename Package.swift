// swift-tools-version: 5.5

import PackageDescription

let package = Package(
    name: "Swiftea",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "Swiftea",
            targets: ["Swiftea"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Swiftea",
            dependencies: []
        ),
        .testTarget(
            name: "SwifteaTests",
            dependencies: ["Swiftea"]
        ),
    ]
)
