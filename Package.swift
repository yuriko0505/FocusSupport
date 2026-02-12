// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FocusSupport",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "FocusSupport", targets: ["FocusSupport"])
    ],
    targets: [
        .executableTarget(
            name: "FocusSupport",
            path: "Sources"
        )
    ]
)
