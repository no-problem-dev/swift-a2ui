---
title: swift-a2ui README
created: 2026-06-27
tags: [a2ui, swift, spm, llm, ui-protocol]
status: active
---

# swift-a2ui

> Google A2UI プロトコルの Swift 完全実装 — LLM エージェントがクライアントにリッチ UI を描画するための型安全なライブラリ群

## 概要

`swift-a2ui` は [A2UI (Agent-to-UI) プロトコル](https://a2ui.org) の Swift 実装です。LLM エージェントが JSON メッセージを通じてクライアント上に宣言的な UI サーフェスを生成・更新・削除し、ユーザーのアクションを受け取ってレスポンスを返す仕組みを、コンパイル時型安全な Swift API として提供します。

### 主な特徴

- **A2UI v0.10 完全対応**: `createSurface` / `updateComponents` / `updateDataModel` / `callFunction` / `actionResponse` の全メッセージ型を実装
- **型安全なカタログ**: Swift の型システムを SSOT とした LLM 向けスキーマ生成（JSON ファイルとの乖離をコンパイル時に検出）
- **AnyView ゼロのジェネリックレンダラー**: カタログを型パラメータとした `A2UISurfaceView<Catalog>` で、型消去なしに SwiftUI へ描画
- **公式プロトコルへの忠実な準拠**: Python SDK (`a2ui.adk` / `a2ui.a2a`) の設計をそのまま Swift に写したモジュール構成
- **マルチエージェント対応**: A2A プロトコル統合とサーフェス所有権台帳によるオーケストレーション

---

## モジュール構成

13 のモジュールを役割ごとに 5 グループに分けて説明します。

### グループ 1 — コアプロトコル層

A2UI の有線フォーマット（JSON）を Swift の型として定義する最下層。SwiftUI も LLM クライアントも依存しない。

| モジュール | 役割 |
|-----------|------|
| **A2UICore** | `ServerMessage` / `ClientMessage` の enum、`CreateSurface` / `UpdateComponents` / `UpdateDataModel` 等の個別メッセージ型、`UserAction`、`DataBinding`、`DynamicString` / `DynamicBoolean` / `DynamicNumber` などのバインダブル値型 |

**主な型:**

```swift
// サーバ → クライアント
public enum ServerMessage: Sendable, Equatable, Codable {
    case createSurface(CreateSurface)
    case updateComponents(UpdateComponents)
    case updateDataModel(UpdateDataModel)
    case deleteSurface(DeleteSurface)
    case callFunction(CallFunctionMessage)
    case actionResponse(ActionResponseMessage)
}

// クライアント → サーバ
public enum ClientMessage: Sendable, Equatable, Codable {
    case action(UserAction)
    case error(ClientError)
    case functionResponse(FunctionResponse)
}
```

---

### グループ 2 — コンポーネントカタログ

LLM が使えるコンポーネントのパレットを型として定義し、その定義から LLM 向け JSON Schema を自動生成する層。

| モジュール | 役割 |
|-----------|------|
| **A2UICatalog** | 18 コンポーネントの Swift 型定義、`ComponentCatalog` プロトコル、`ComponentSchema` / `SchemaRenderer` による型駆動スキーマ生成、カテゴリ enum (`display` / `layout` / `input`) |

**内蔵コンポーネント（`BasicComponentCatalog`）:**

| カテゴリ | コンポーネント |
|---------|--------------|
| Display | `Text`, `Image`, `Icon`, `Video`, `AudioPlayer` |
| Layout | `Row`, `Column`, `List`, `Card`, `Tabs`, `Modal`, `Divider` |
| Input | `Button`, `TextField`, `CheckBox`, `ChoicePicker`, `Slider`, `DateTimeInput` |

スキーマは Swift 型から自動生成されるため、実装とスキーマが乖離することはない:

```swift
// スキーマ生成
let schema: String = BasicComponentCatalog.catalogSchemaJSON()

// カタログ ID
let id: String = BasicComponentCatalog.catalogId
// → "https://a2ui.org/specification/v0_10/catalogs/basic/catalog.json"
```

---

### グループ 3 — LLM プロンプト・パーサー

エージェントに渡すシステムプロンプトの組み立てと、LLM 出力からの A2UI メッセージ抽出を担う。

| モジュール | 役割 |
|-----------|------|
| **A2UIPrompt** | `A2UIPromptBuilder` — システムプロンプトの組み立て（role / workflow rules / UI description / スキーマブロック）。カタログ・メッセージ種別の pruning（allowlist による絞り込み）。`A2UIExample` — 型付きコンポーネントから生成する参照サーフェス例文 |
| **A2UIPromptCompact** | `A2UIPromptCompactBuilder` — `functions` を使わないアプリ向けに common_types から FunctionCall 型を除去した軽量版 |
| **A2UIParser** | `A2UIStreamingParser` — ストリーミング LLM 出力から `<a2ui-json>` ブロックをインクリメンタル抽出。`A2UIPayloadFixer` — LLM が生成する JSON の典型的な崩れを自動補正。`JSONSanitizer` |

**プロンプトの組み立て:**

```swift
// 標準 builder（カタログ・メッセージ全種）
let builder = A2UIPromptBuilder()
let prompt = builder.buildSystemPrompt(
    role: "You are a helpful assistant that renders UI.",
    uiDescription: "Show a card with a title and a confirm button."
)

// presenter プリセット（コンテンツ提示向け 9 コンポーネント + 3 メッセージに絞る）
let presenterBuilder = A2UIPromptBuilder.presenter()

// カスタム pruning
let builder = A2UIPromptBuilder(
    allowedComponents: ["Text", "Column", "Row", "Button", "Image"],
    allowedMessages: ["CreateSurfaceMessage", "UpdateComponentsMessage"]
)
```

**ストリーミングパーサーの使い方:**

```swift
let parser = A2UIStreamingParser()

for chunk in llmStream {
    let parts = parser.feed(chunk)
    for part in parts {
        switch part {
        case .messages(let messages):
            // A2UI ServerMessage 配列を描画系へ流す
            await surface.apply(messages)
        case .text(let text):
            // プレーンテキスト部分
            print(text)
        }
    }
}
let finalParts = parser.finalize()
```

---

### グループ 4 — サーフェス状態 / レンダラー

クライアント上のサーフェス状態管理と SwiftUI 描画を担う。

| モジュール | 役割 |
|-----------|------|
| **A2UISurface** | `DataModel` — JSON Pointer による読み書きとリアクティブなパス購読（Bubble & Cascade 通知）。`ComponentValidator`、テンプレート展開 (`ChildList`) |
| **A2UIRuntime** | `DataContext` — スコープ付きバインディング解決。`TemplateExpander` — `{componentId, path}` テンプレートをコレクションスコープで展開 |
| **A2UITyped** | `A2UICatalog` プロトコル（`associatedtype Node: ComponentNode`）、`CombinedNode<Primary, Fallback>` による型安全なカタログ合成、`BasicCatalog`（`BasicComponent` を `ComponentNode` として公開）、`A2UIValidation` |
| **A2UITypedRenderer** | `RenderableCatalog` プロトコル、`A2UISurfaceView<Catalog>` (SwiftUI View)、`NodeView<Catalog>`、`RenderContext<Catalog>`（双方向バインディング / checks 評価 / 子レンダリングの文脈） |

**A2UISurfaceView の使い方:**

```swift
import SwiftUI
import A2UITypedRenderer

// 1. サーフェスを作成（@Observable なので @State に持てる）
@State var surface = TypedSurface<BasicCatalog>(rootId: "root", nodes: [])

// 2. サーフェスメッセージを適用するハンドラ
func apply(_ message: ServerMessage) {
    switch message {
    case .updateComponents(let msg):
        guard let nodes = try? TypedSurface<BasicCatalog>.decodeNodes(
            fromJSONArray: JSONEncoder().encode(msg.components)
        ) else { return }
        surface.applyUpdateComponents(nodes)
    case .updateDataModel(let msg):
        surface.applyUpdateDataModel(path: msg.path, value: msg.value)
    default:
        break
    }
}

// 3. SwiftUI に埋め込む
var body: some View {
    A2UISurfaceView(surface, busy: isGenerating)
}
```

**カスタムカタログの合成:**

```swift
// 独自コンポーネントを BasicCatalog に上乗せ
typealias AppCatalog = Catalog<CombinedNode<MyNode, BasicComponent>>

// BasicEmbeddingNode 準拠で BasicCatalog のレンダラーを再利用
extension MyNode: BasicEmbeddingNode { ... }
```

---

### グループ 5 — エージェント統合 / オーケストレーション

LLM エージェントへの A2UI ツール提供と、マルチエージェント構成を担う。

| モジュール | 役割 |
|-----------|------|
| **A2UIAgentTool** | `SendA2UIToClientTool<Catalog>` — LLM が `send_a2ui_json_to_client` ツールを呼ぶ公式パターン。JSON の解析・自動補正・バリデーション（allowlist 準拠）を行い、`validated_a2ui_json` を返す。`A2UIToolResultExtractor` — ツール結果から `[ServerMessage]` を取り出す |
| **A2UIAgent** | `A2UIPresenterAgent` — presenter（コンテンツ提示）型エージェントの自己記述一式。`systemPrompt()` / `tools()` / `agentExtension()` / `hostOutputConstraint()` を提供。ホストは注入するだけで UI の全知識はこのモジュールに閉じる |
| **A2UIA2A** | A2A プロトコルとの統合。`Part.a2ui(_:)` で A2UI メッセージを `application/a2ui+json` データパートとして包む。`A2UIExtension` — エージェントカードへの A2UI プロトコル宣言。`A2UIClientCapabilities` / `A2UIClientDataModel` / `A2UIMessageMetadata` |
| **A2UIOrchestration** | `SurfaceOwnership` — サーフェス所有権台帳（どのエージェントがどのサーフェスを持つか）。`owner(ofUserActionIn:)` による確定的な UserAction ルーティング。`outboundMetadata(_:capabilities:for:)` によるデータモデル・ストリッピング（エージェント間のデータ漏洩防止） |

**A2UIPresenterAgent の注入例:**

```swift
import A2UIAgent
import A2ACore
import LLMClient

// presenter エージェントに必要なものはすべてライブラリ側が持つ
let agentName = A2UIPresenterAgent.defaultName

// 1. system prompt
let systemPrompt = A2UIPresenterAgent.systemPrompt(language: "Japanese")

// 2. tools（カタログパレットはカスタマイズ可能）
let tools = A2UIPresenterAgent.tools(
    components: ["Column", "Row", "Text", "Image", "Icon", "List", "Card", "Button", "Divider"]
)

// 3. A2A card の extensions に宣言
let extension = A2UIPresenterAgent.agentExtension()

// 4. オーケストレータの system prompt に注入する制約
let constraint = A2UIPresenterAgent.hostOutputConstraint(agentName: agentName)
```

**オーケストレーション（SurfaceOwnership）:**

```swift
import A2UIOrchestration

var ownership = SurfaceOwnership()

// サブエージェントの応答を受け取るたびに所有権を記録
ownership.record(surfacesCreatedIn: responseparts, by: "a2ui")

// UserAction をルーティング（LLM 呼び出し不要）
if let agent = ownership.owner(ofUserActionIn: incomingParts) {
    // 対象エージェントへ直接転送
    await router.send(to: agent, parts: incomingParts)
}

// 送信前にデータモデルをエージェントの所有サーフェスだけに絞る
let metadata = try ownership.outboundMetadata(
    baseMetadata,
    capabilities: clientCapabilities,
    for: "a2ui"
)
```

---

## インストール

### Swift Package Manager

`Package.swift` の `dependencies` に追加:

```swift
.package(url: "https://github.com/no-problem-dev/swift-a2ui.git", from: "0.0.1"),
```

ターゲットの `dependencies` で必要なモジュールを列挙:

```swift
.target(
    name: "MyApp",
    dependencies: [
        // 最小構成（コアのみ）
        .product(name: "A2UICore", package: "swift-a2ui"),

        // プロンプト組み立て + パーサー
        .product(name: "A2UIPrompt", package: "swift-a2ui"),
        .product(name: "A2UIParser", package: "swift-a2ui"),

        // SwiftUI レンダラー（iOS/macOS UI）
        .product(name: "A2UITypedRenderer", package: "swift-a2ui"),

        // LLM エージェントツール
        .product(name: "A2UIAgentTool", package: "swift-a2ui"),

        // presenter エージェント自己記述
        .product(name: "A2UIAgent", package: "swift-a2ui"),

        // A2A 統合 / オーケストレーション
        .product(name: "A2UIA2A", package: "swift-a2ui"),
        .product(name: "A2UIOrchestration", package: "swift-a2ui"),
    ]
)
```

---

## 対応プラットフォーム

| プラットフォーム | 最小バージョン |
|----------------|--------------|
| macOS | 14.0 (Sonoma) |
| iOS | 17.0 |

Swift ツールズバージョン: **6.2**

---

## 外部依存パッケージ

| パッケージ | 用途 |
|-----------|------|
| `no-problem-dev/swift-structured-data` | JSON パース / シリアライズ (`StructuredValue`, `JSONParser`) |
| `no-problem-dev/swift-a2a` | A2A プロトコルコア (`AgentCard`, `Part`, `StreamResponse`) |
| `no-problem-dev/swift-design-system` | SwiftUI デザイントークン（カラー / スペーシング / モーション / Glass Card） |
| `no-problem-dev/swift-markdown-view` | Text コンポーネントの Markdown レンダリング |
| `no-problem-dev/swift-llm-client` | `Tool` / `TurnEndingTool` プロトコル（`SendA2UIToClientTool` の基底） |

---

## ライセンス

[LICENSE](./LICENSE) を参照してください。

---

最終更新: 2026-06-27
