// swift-tools-version:5.9
import PackageDescription

/// The shared layer built as a package so its tests run on the Mac in seconds.
///
/// Running them through an Xcode test target would mean compiling the iPhone app and
/// the embedded Watch app for the simulator and booting it — minutes of work and
/// several gigabytes, to exercise code that is pure logic. The parsing and formatting
/// rules are where a silent wrong-number bug would live, so these tests have to be
/// cheap enough to run constantly.
let package = Package(
    name: "GlicemiaCore",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "GlicemiaCore", path: "Sources/Shared"),
        .testTarget(name: "GlicemiaCoreTests", dependencies: ["GlicemiaCore"], path: "Tests"),
    ]
)
