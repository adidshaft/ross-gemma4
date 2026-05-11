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
        .package(url: "https://github.com/mattt/llama.swift", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "Ross",
            dependencies: [
                .product(name: "LlamaSwift", package: "llama.swift")
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
