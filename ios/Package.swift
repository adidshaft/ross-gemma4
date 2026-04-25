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
    dependencies: [
        .package(url: "https://github.com/pgorzelany/swift-gemma-runtime", exact: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "Ross",
            dependencies: [
                .product(name: "SwiftGemmaRuntime", package: "swift-gemma-runtime")
            ],
            path: "Ross",
            exclude: [
                "Resources/Info.plist",
                "Ross.entitlements"
            ],
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "RossTests",
            dependencies: ["Ross"],
            path: "Tests/RossTests"
        )
    ]
)
