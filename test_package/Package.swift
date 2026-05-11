// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "test_package",
    platforms: [.iOS(.v17), .macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/mattt/llama.swift.git", branch: "main")
    ],
    targets: [
        .executableTarget(name: "TestLlama", dependencies: [.product(name: "LlamaSwift", package: "llama.swift")])
    ]
)
