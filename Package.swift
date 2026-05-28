// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-a2ui",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "A2UICore", targets: ["A2UICore"]),
        .library(name: "A2UICatalog", targets: ["A2UICatalog"]),
        .library(name: "A2UIPrompt", targets: ["A2UIPrompt"]),
        .library(name: "A2UIParser", targets: ["A2UIParser"]),
        .library(name: "A2UISurface", targets: ["A2UISurface"]),
        .library(name: "A2UIRuntime", targets: ["A2UIRuntime"]),
    ],
    targets: [
        .target(name: "A2UICore"),
        .target(name: "A2UICatalog", dependencies: ["A2UICore"],
                resources: [.copy("Resources")]),
        .target(name: "A2UIPrompt", dependencies: ["A2UICatalog"],
                resources: [.copy("Resources")]),
        .target(name: "A2UIParser", dependencies: ["A2UICore"]),
        .target(name: "A2UISurface", dependencies: ["A2UICore"]),
        .target(name: "A2UIRuntime", dependencies: ["A2UICore", "A2UISurface"]),
        .testTarget(name: "A2UICoreTests", dependencies: ["A2UICore"],
                    resources: [.copy("Fixtures")]),
        .testTarget(name: "A2UICatalogTests", dependencies: ["A2UICatalog"],
                    resources: [.copy("Fixtures")]),
        .testTarget(name: "A2UIPromptTests", dependencies: ["A2UIPrompt"]),
        .testTarget(name: "A2UIParserTests", dependencies: ["A2UIParser"]),
        .testTarget(name: "A2UISurfaceTests", dependencies: ["A2UISurface"]),
        .testTarget(name: "A2UIRuntimeTests", dependencies: ["A2UIRuntime"]),
    ]
)
