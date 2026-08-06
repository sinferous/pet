// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DesktopPet",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        // Pure logic (Foundation only) — unit-testable on any platform.
        .target(
            name: "DesktopPetCore",
            path: "Sources/DesktopPetCore"
        ),
        // The macOS app itself (AppKit / SpriteKit / SwiftUI).
        .executableTarget(
            name: "DesktopPet",
            dependencies: ["DesktopPetCore"],
            path: "Sources/DesktopPet"
        ),
        .testTarget(
            name: "DesktopPetTests",
            dependencies: ["DesktopPetCore"],
            path: "Tests/DesktopPetTests"
        )
    ]
)
