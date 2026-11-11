// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FlashPaste",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure logic, no AppKit event code: unit-tested.
        .target(name: "FlashPasteCore"),
        .executableTarget(
            name: "FlashPaste",
            dependencies: ["FlashPasteCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .testTarget(name: "FlashPasteCoreTests", dependencies: ["FlashPasteCore"]),
    ]
)
