# ``A2UIA2A``

A2UI メッセージと A2A Part の相互変換・メタデータ語彙・エージェント拡張宣言を提供する A2A 統合モジュール。

## Overview

`A2UIA2A` は A2UI プロトコルを A2A（Agent-to-Agent）プロトコルに統合します。Python SDK の `a2ui.a2a` モジュールに対応します。A2UI メッセージは `application/a2ui+json` の MIME タイプを持つ A2A `Part` として転送され、このモジュールがその符号化・復号化を担います。

`A2UIMediaType` は公式 MIME タイプ文字列 (`application/a2ui+json`) と後方互換のメタデータキーを保持します。`Part` への拡張（`Part.a2ui(_:)` ファクトリ・`part.a2uiServerMessage()`・`part.a2uiClientMessage()`・`part.a2uiUserAction`）は A2A の `Part` 型に直接追加され、A2UI の内容を判定・デコードできます。

`A2UIExtension` は A2A の AgentCard への A2UI 拡張宣言（`agentExtension(supportedCatalogIds:)`）と、リモートカードからの宣言読み取り（`declarations(in:)`・`currentDeclaration(in:)`）を提供します。`A2UIMessageMetadata` はクライアント能力（`A2UIClientCapabilities`）とクライアントデータモデル（`A2UIClientDataModel`）を A2A メタデータへ埋め込む関数を持ちます。

```swift
import A2UIA2A
import A2UICore

// ServerMessage を A2A Part に変換する
let message = ServerMessage.create(CreateSurface(...))
let part = try Part.a2ui(message)

// 受信した Part から A2UI メッセージを取り出す
if let serverMsg = try receivedPart.a2uiServerMessage() {
    print("受信:", serverMsg)
}
```

## Topics

### Part コーディング

- ``A2UIMediaType``

### エージェント拡張宣言

- ``A2UIExtension``

### メッセージメタデータ

- ``A2UIMessageMetadata``
- ``A2UIClientCapabilities``
- ``A2UIClientDataModel``
