// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-a2ui",
    defaultLocalization: "en",
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
        // Official tool-call generation pattern (mirror of the Python SDK's a2ui.adk):
        // the send_a2ui_json_to_client tool + the tool-result → ServerMessage extractor.
        .library(name: "A2UIAgentTool", targets: ["A2UIAgentTool"]),
        .library(name: "A2UISubagent", targets: ["A2UISubagent"]),
        // Self-description of the presenter (content-presentation) A2UI agent:
        // system prompt, official tool, card extension, host delegation constraint.
        // Hosts inject these into their executor the same way they inject any worker agent.
        .library(name: "A2UIAgent", targets: ["A2UIAgent"]),
        // A2A integration (mirror of the Python SDK's a2ui.a2a): the A2UI agent extension
        // declaration, ServerMessage/ClientMessage ⇄ A2A Part coding, and the message
        // metadata vocabulary (a2uiClientCapabilities / a2uiClientDataModel).
        .library(name: "A2UIA2A", targets: ["A2UIA2A"]),
        // Orchestration policy over A2UIA2A (mirror of the official orchestrator sample):
        // surface ownership ledger, deterministic userAction routing, data-model stripping.
        // Pure functions over A2A parts — host runtimes wire these in as hooks.
        .library(name: "A2UIOrchestration", targets: ["A2UIOrchestration"]),
        // AG-UI integration (mirror of the official ag-ui a2ui-middleware wire contract):
        // A2UI ops ⇄ ACTIVITY_SNAPSHOT (paint / lifecycle snapshots), the
        // forwardedProps.a2uiAction return path, and the schema context declaration.
        .library(name: "A2UIAGUI", targets: ["A2UIAGUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
        .package(url: "https://github.com/no-problem-dev/swift-structured-data.git", from: "3.0.0"),
        .package(url: "https://github.com/no-problem-dev/swift-a2a.git", .upToNextMinor(from: "0.8.0")),
        .package(url: "https://github.com/no-problem-dev/swift-agui.git", .upToNextMinor(from: "0.2.0")),
        // Uses mediaViewable, the SurfaceStyle environment, Glass Card, and the motion tokens.
        .package(url: "https://github.com/no-problem-dev/swift-design-system.git", from: "3.0.0"),
        .package(url: "https://github.com/no-problem-dev/swift-markdown-view.git", from: "6.0.0"),
        .package(url: "https://github.com/no-problem-dev/swift-llm-client.git", from: "4.0.0"),
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
        .target(name: "A2UIRuntime", dependencies: ["A2UICore", "A2UISurface"]),
        // Generic catalog/node layer. No SwiftUI — builds on macOS for fast type-level iteration.
        .target(name: "A2UITyped", dependencies: ["A2UICore", "A2UICatalog", "A2UISurface"]),
        // Generic SwiftUI renderer: A2UISurfaceView<Catalog> dispatches CatalogNode via a recursive
        // generic NodeView<Catalog> with no AnyView/type erasure. Builds on macOS (plain SwiftUI).
        .target(name: "A2UITypedRenderer", dependencies: [
            "A2UICore", "A2UICatalog", "A2UISurface", "A2UIRuntime", "A2UITyped",
            .product(name: "DesignSystem", package: "swift-design-system"),
            .product(name: "SwiftMarkdownView", package: "swift-markdown-view"),
            // Reads the design-system palette as Markdown colors. Without it MarkdownView
            // falls back to system semantic colors and ignores the A2UI theme entirely.
            .product(name: "SwiftMarkdownViewDesignSystem", package: "swift-markdown-view"),
        ], resources: [.process("Resources")]),
        // Tool-call generation pattern. Depends on the LLM tool layer the same way the Python
        // SDK's a2ui.adk depends on google-adk. UI-free — tests run on the CLI.
        .target(name: "A2UIAgentTool", dependencies: [
            "A2UICore", "A2UIParser", "A2UIPrompt", "A2UITyped",
            .product(name: "LLMClient", package: "swift-llm-client"),
            .product(name: "LLMTool", package: "swift-llm-client"),
        ]),
        // Two-stage generation pattern (@ag-ui/a2ui-toolkit port). The outer `generate_a2ui`
        // tool carries intent only; a subagent LLM call is forced onto `render_a2ui` so the
        // model has no API-level option to emit prose instead of a tool call. Validation
        // retries live here too. Append-only: each call emits exactly one `createSurface`
        // (v1.0 carries components + dataModel inline), so surfaces stack up like a
        // transcript and are never rewritten. UI-free — tests run on the CLI.
        .target(name: "A2UISubagent", dependencies: [
            "A2UICore", "A2UIParser", "A2UITyped",
            .product(name: "LLMClient", package: "swift-llm-client"),
            .product(name: "LLMTool", package: "swift-llm-client"),
            .product(name: "StructuredDataCore", package: "swift-structured-data"),
        ]),
        // Presenter agent self-description. Owns ALL the UI knowledge an a2ui worker needs
        // (role, UI rules, presenter-pruned schema + example via the tool) so consuming apps
        // only inject it — the layer that makes a2ui symmetric with other worker agents.
        // UI-free — tests run on the CLI.
        .target(name: "A2UIAgent", dependencies: [
            "A2UICore", "A2UIPrompt", "A2UITyped", "A2UIAgentTool", "A2UIA2A",
            .product(name: "A2ACore", package: "swift-a2a"),
            .product(name: "LLMClient", package: "swift-llm-client"),
            .product(name: "LLMTool", package: "swift-llm-client"),
        ]),
        // A2A integration. Depends on A2ACore the same way the Python SDK's a2ui.a2a
        // depends on a2a-sdk. UI-free — tests run on the CLI.
        .target(name: "A2UIA2A", dependencies: [
            "A2UICore",
            .product(name: "A2ACore", package: "swift-a2a"),
        ]),
        // Orchestration policy. Same layer as the official samples/agent/adk/orchestrator —
        // composition logic over the protocol vocabulary, kept UI- and runtime-free.
        .target(name: "A2UIOrchestration", dependencies: [
            "A2UICore", "A2UIA2A",
            .product(name: "A2ACore", package: "swift-a2a"),
        ]),
        // AG-UI integration. Depends on AGUICore the same way A2UIA2A depends on A2ACore.
        // Mirrors the client-side wire contract of ag-ui's official a2ui-middleware
        // (activityType "a2ui-surface", content.a2ui_operations, forwardedProps.a2uiAction),
        // carrying the ecosystem's current A2UI version instead of the middleware's pinned v0.9.
        // UI-free — tests run on the CLI.
        .target(name: "A2UIAGUI", dependencies: [
            "A2UICore",
            .product(name: "AGUICore", package: "swift-agui"),
        ]),
        .testTarget(name: "A2UICoreTests", dependencies: ["A2UICore"],
                    resources: [.copy("Fixtures")]),
        .testTarget(name: "A2UIA2ATests", dependencies: ["A2UIA2A"]),
        .testTarget(name: "A2UIAGUITests", dependencies: ["A2UIAGUI"]),
        .testTarget(name: "A2UIOrchestrationTests", dependencies: ["A2UIOrchestration"]),
        .testTarget(name: "A2UICatalogTests", dependencies: ["A2UICatalog"],
                    resources: [.copy("Fixtures")]),
        .testTarget(name: "A2UIPromptTests", dependencies: ["A2UIPrompt"]),
        .testTarget(name: "A2UIPromptCompactTests", dependencies: ["A2UIPromptCompact"]),
        .testTarget(name: "A2UIParserTests", dependencies: ["A2UIParser"]),
        .testTarget(name: "A2UISurfaceTests", dependencies: ["A2UISurface"]),
        .testTarget(name: "A2UIRuntimeTests", dependencies: ["A2UIRuntime"]),
        .testTarget(name: "A2UITypedTests", dependencies: ["A2UITyped"]),
        .testTarget(name: "A2UITypedRendererTests", dependencies: ["A2UITypedRenderer"]),
        .testTarget(name: "A2UIAgentToolTests", dependencies: ["A2UIAgentTool"]),
        .testTarget(name: "A2UISubagentTests", dependencies: ["A2UISubagent"]),
        .testTarget(name: "A2UIAgentTests", dependencies: ["A2UIAgent"]),
    ]
)
