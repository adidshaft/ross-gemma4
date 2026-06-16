// swift-tools-version: 6.1

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
        .package(url: "https://github.com/mattt/llama.swift", .upToNextMajor(from: "2.9665.0")),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", .upToNextMajor(from: "3.31.3")),
        .package(url: "https://github.com/huggingface/swift-huggingface", from: "0.9.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.20")
    ],
    targets: [
        .executableTarget(
            name: "Ross",
            dependencies: [
                .product(name: "LlamaSwift", package: "llama.swift"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
                .product(name: "Tokenizers", package: "swift-transformers"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
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
