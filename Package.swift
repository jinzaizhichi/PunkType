// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PunkType",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "PunkType",
            path: "Sources"
        )
    ]
)
