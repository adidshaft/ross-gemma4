// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Ross",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Ross",
            targets: ["Ross"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Ross",
            path: "Ross",
            exclude: ["Resources"]
        )
    ]
)
