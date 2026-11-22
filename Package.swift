// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Lookhere",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Lookhere",
            path: "Sources/Lookhere",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
    ]
)
