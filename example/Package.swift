// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "WarpYAMLExample",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "warp-yaml", targets: ["warp-yaml"])
    ],
    dependencies: [
        // The Front, kept outside the package that spends with it.
        .package(path: "..")
    ],
    targets: [
        // Writes each YAML text's document beside it, as `.warp` bytes. It
        // runs nothing.
        .executableTarget(
            name: "warp-yaml",
            dependencies: [
                .product(name: "WarpYAML", package: "warp-frontend-yaml")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
