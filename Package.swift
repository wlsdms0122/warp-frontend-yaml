// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "WarpYAML",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "WarpYAML", targets: ["WarpYAML"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0")
    ],
    targets: [
        // YAML texts and declaration files in, `.warp` bytes and their origin
        // out.
        .target(
            name: "WarpYAML",
            dependencies: [
                .product(name: "Yams", package: "Yams")
            ]
        ),
        .testTarget(
            name: "WarpYAMLTests",
            dependencies: [
                "WarpYAML"
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
