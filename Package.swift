// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-a2ui",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "A2UICore", targets: ["A2UICore"]),
        .library(name: "A2UICatalog", targets: ["A2UICatalog"]),
        .library(name: "A2UIPrompt", targets: ["A2UIPrompt"]),
        .library(name: "A2UIPromptCompact", targets: ["A2UIPromptCompact"]),
        .library(name: "A2UIParser", targets: ["A2UIParser"]),
        .library(name: "A2UISurface", targets: ["A2UISurface"]),
        .library(name: "A2UIRuntime", targets: ["A2UIRuntime"]),
        // Generic, UI-agnostic typed catalog core: ComponentNode / CatalogNode / A2UICatalog.
        // The compile-time-type-safe successor to the stringly-typed dispatch (see strategy doc).
        .library(name: "A2UITyped", targets: ["A2UITyped"]),
        // Generic, type-safe SwiftUI renderer over any A2UICatalog (zero type erasure).
        .library(name: "A2UITypedRenderer", targets: ["A2UITypedRenderer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/no-problem-dev/swift-structured-data.git", from: "1.3.0"),
        .package(url: "https://github.com/no-problem-dev/swift-design-system.git", from: "1.0.0"),
        .package(url: "https://github.com/no-problem-dev/swift-markdown-view.git", branch: "main"),
    ],
    targets: [
        .target(name: "A2UICore", dependencies: [
            .product(name: "StructuredDataCore", package: "swift-structured-data"),
            .product(name: "JSONParsing", package: "swift-structured-data"),
        ]),
        // No resources: the catalog schema is generated from Swift types (BasicCatalogSchema).
        .target(name: "A2UICatalog", dependencies: ["A2UICore"]),
        .target(name: "A2UIPrompt", dependencies: [
            "A2UICore", "A2UICatalog",
            .product(name: "JSONParsing", package: "swift-structured-data"),
        ], resources: [.process("Resources")]),
        .target(name: "A2UIPromptCompact", dependencies: ["A2UICore", "A2UICatalog", "A2UIPrompt"]),
        .target(name: "A2UIParser", dependencies: ["A2UICore"]),
        .target(name: "A2UISurface", dependencies: ["A2UICore"]),
        .target(name: "A2UIRuntime", dependencies: ["A2UICore", "A2UISurface", "A2UICatalog"]),
        // Generic catalog/node layer. No SwiftUI — builds on macOS for fast type-level iteration.
        .target(name: "A2UITyped", dependencies: ["A2UICore", "A2UICatalog"]),
        // Generic SwiftUI renderer: A2UISurfaceView<Catalog> dispatches CatalogNode via a recursive
        // generic NodeView<Catalog> with no AnyView/type erasure. Builds on macOS (plain SwiftUI).
        .target(name: "A2UITypedRenderer", dependencies: [
            "A2UICore", "A2UICatalog", "A2UISurface", "A2UIRuntime", "A2UITyped",
            .product(name: "DesignSystem", package: "swift-design-system"),
            .product(name: "SwiftMarkdownView", package: "swift-markdown-view"),
        ]),
        .testTarget(name: "A2UICoreTests", dependencies: ["A2UICore"],
                    resources: [.copy("Fixtures")]),
        .testTarget(name: "A2UICatalogTests", dependencies: ["A2UICatalog"],
                    resources: [.copy("Fixtures")]),
        .testTarget(name: "A2UIPromptTests", dependencies: ["A2UIPrompt"]),
        .testTarget(name: "A2UIPromptCompactTests", dependencies: ["A2UIPromptCompact"]),
        .testTarget(name: "A2UIParserTests", dependencies: ["A2UIParser"]),
        .testTarget(name: "A2UISurfaceTests", dependencies: ["A2UISurface"]),
        .testTarget(name: "A2UIRuntimeTests", dependencies: ["A2UIRuntime"]),
        .testTarget(name: "A2UITypedTests", dependencies: ["A2UITyped"]),
        .testTarget(name: "A2UITypedRendererTests", dependencies: ["A2UITypedRenderer"]),
    ]
)
