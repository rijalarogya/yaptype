// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Yaptype",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Yaptype", targets: ["Yaptype"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", from: "0.9.0"),
        .package(url: "https://github.com/huggingface/swift-transformers.git", .upToNextMinor(from: "1.1.6"))
    ],
    targets: [
        .executableTarget(
            name: "Yaptype",
            dependencies: [
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
                .product(name: "Hub", package: "swift-transformers")
            ],
            path: "Yaptype",
            exclude: [
                "Resources/Yaptype.entitlements"
            ],
            resources: [
                .process("Resources/Assets.xcassets")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "YaptypeTests",
            dependencies: ["Yaptype"],
            path: "YaptypeTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
