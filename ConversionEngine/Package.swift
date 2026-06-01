// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ConversionEngine",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11),
        .macOS(.v14)
    ],
    products: [
        .library(name: "ConversionEngine", targets: ["ConversionEngine"])
    ],
    targets: [
        .target(name: "ConversionEngine"),
        .testTarget(
            name: "ConversionEngineTests",
            dependencies: ["ConversionEngine"],
            resources: [.copy("Fixtures")]
        )
    ]
)
