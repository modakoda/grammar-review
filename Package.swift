// swift-tools-version: 6.2
import PackageDescription

let mainActorByDefault: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "GrammarReview",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "GrammarReview", targets: ["GrammarReviewApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", .upToNextMajor(from: "2.10.0")),
    ],
    targets: [
        .target(name: "GrammarModels"),
        .target(name: "GrammarEngine", dependencies: ["GrammarModels"]),
        .target(name: "GrammarAccessibility", dependencies: ["GrammarModels"], swiftSettings: mainActorByDefault),
        .target(name: "GrammarOverlay", dependencies: ["GrammarModels"], swiftSettings: mainActorByDefault),
        .target(name: "GrammarAppUI", dependencies: ["GrammarModels"], swiftSettings: mainActorByDefault),
        .target(
            name: "GrammarEditor",
            dependencies: ["GrammarModels", "GrammarEngine", "GrammarOverlay"],
            swiftSettings: mainActorByDefault
        ),
        .executableTarget(
            name: "GrammarReviewApp",
            dependencies: [
                "GrammarModels", "GrammarEngine", "GrammarAccessibility", "GrammarOverlay", "GrammarAppUI", "GrammarEditor",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            swiftSettings: mainActorByDefault,
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(name: "GrammarEngineTests", dependencies: ["GrammarEngine"]),
        .testTarget(name: "GrammarAccessibilityTests", dependencies: ["GrammarAccessibility"]),
        .testTarget(name: "GrammarOverlayTests", dependencies: ["GrammarOverlay"]),
        .testTarget(name: "GrammarAppUITests", dependencies: ["GrammarAppUI"]),
        .testTarget(name: "GrammarEditorTests", dependencies: ["GrammarEditor"]),
        .testTarget(name: "GrammarReviewAppTests", dependencies: ["GrammarReviewApp"]),
    ]
)
