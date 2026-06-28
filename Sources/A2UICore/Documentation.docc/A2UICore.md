# ``A2UICore``

A2UI プロトコルの共有メッセージ型・コンポーネントプロトコル・動的値型を定義するコア基盤モジュール。

## Overview

`A2UICore` は `swift-a2ui` パッケージ全体の土台です。LLM エージェントとクライアント間で交わされるすべてのメッセージ型を所有し、他のすべての A2UI モジュールがこのモジュールに依存します。ビジネスロジック・SwiftUI・LLM クライアントへの依存は一切持たず、任意のアーキテクチャ層でインポートできます。

プロトコルは `ServerMessage` と `ClientMessage` の 2 方向で整理されています。エージェント（サーバー）はサーフェスの作成（`CreateSurface`）・コンポーネントの更新（`UpdateComponents`）・データモデルの更新（`UpdateDataModel`）・サーフェスの削除（`DeleteSurface`）をクライアントに送信します。クライアントはユーザー操作（`UserAction`）・関数レスポンス（`FunctionResponse`）・エラー（`ClientError`）をエージェントに返します。

コンポーネントの定義は `A2UIComponentProtocol` を介して型安全に表現されます。プロパティは `DynamicString`・`DynamicBoolean`・`DynamicNumber`・`DynamicValue` などの動的型で保持され、`DataBinding` を使ってデータモデルのパスにバインドできます。

パッケージは以下のモジュール群で構成されています。**パース系**では `A2UIParser` が LLM ストリームからメッセージを抽出します。**レンダリング系**では `A2UISurface` がコンポーネントツリーとデータモデルを保持し、`A2UITypedRenderer` が SwiftUI ビューをゼロ型消去で描画します。**エージェント系**では `A2UIAgent` がプレゼンターエージェントの自己記述を提供し、`A2UIAgentTool` がツールコール生成パターンを、`A2UIA2A` が A2A プロトコルとのコーディングを、`A2UIOrchestration` がマルチエージェント編成のオーケストレーションポリシーを担います。**プロンプト系**では `A2UIPrompt` がシステムプロンプト生成を、`A2UIPromptCompact` がトークン削減最適化を担います。**型付け**では `A2UITyped` がコンパイル時型安全なカタログノードを提供し、**カタログ**では `A2UICatalog` がコンポーネント定義とスキーマ記述を、**実行**では `A2UIRuntime` がテンプレート展開と関数評価を担います。

```swift
import A2UICore

// エージェントがクライアントへ送る最初のメッセージ
let create = ServerMessage.create(CreateSurface(
    surfaceId: "main",
    rootComponentId: "root",
    components: [],
    dataModel: nil,
    functions: []
))

// クライアントからエージェントへ届くユーザー操作
let action = ClientMessage.action(UserAction(
    surfaceId: "main",
    actionId: "submit",
    callId: "call-1"
))
```

## Topics

### メッセージ（サーバー → クライアント）

- ``ServerMessage``
- ``CreateSurface``
- ``UpdateComponents``
- ``UpdateDataModel``
- ``DeleteSurface``

### メッセージ（クライアント → サーバー）

- ``ClientMessage``
- ``UserAction``
- ``FunctionResponse``
- ``CallFunctionMessage``
- ``ActionResponseMessage``
- ``ActionResponse``
- ``ClientError``

### コンポーネントプロトコル

- ``A2UIComponentProtocol``

### 動的値型

- ``DynamicString``
- ``DynamicBoolean``
- ``DynamicNumber``
- ``DynamicValue``
- ``DynamicStringList``
- ``DataBinding``
- ``ChildList``

### アクション・関数

- ``Action``
- ``EventAction``
- ``FunctionCall``
- ``CallableFrom``
- ``FunctionReturnType``
- ``CheckRule``

### アクセシビリティ

- ``AccessibilityAttributes``

### バージョン・定数

- ``A2UIVersion``
- ``A2UIToolConstants``
