// swift-tools-version: 5.9
import PackageDescription

// The platform-independent domain core. The SwiftUI application is built through
// the generated Xcode project (project.yml), not through this package, so that
// `swift test` stays runnable on any Swift 5.9+ toolchain and never needs UIKit.
let package = Package(
    name: "SecondShot",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "SecondShotCore", targets: ["SecondShotCore"])
    ],
    targets: [
        .target(
            name: "SecondShotCore",
            path: "Sources/SecondShotCore"
        ),
        .testTarget(
            name: "SecondShotCoreTests",
            dependencies: ["SecondShotCore"],
            path: "Tests/SecondShotCoreTests"
        )
    ]
)
