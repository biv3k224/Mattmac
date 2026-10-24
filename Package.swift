// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "mattmac",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "mattmac", targets: ["mattmac"])
    ],
    targets: [
        .executableTarget(
            name: "mattmac",
            path: "Sources",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
