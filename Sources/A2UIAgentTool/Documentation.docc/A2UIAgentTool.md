# ``A2UIAgentTool``

LLM ツールコール生成パターン — `send_a2ui_json_to_client` ツールとツール結果エクストラクターを提供する。

## Overview

`A2UIAgentTool` は A2UI エージェントが LLM に提供する公式ツール `send_a2ui_json_to_client` の Swift 実装です。Python SDK の `a2ui.adk` モジュールに対応します。LLM はこのツールを呼び出すことで A2UI JSON をクライアントに送信し、UI をレンダリング・更新します。

`SendA2UIToClientTool<Catalog>` は `LLMTool` プロトコルに準拠したジェネリック型です。ツール定義（名前・説明・引数スキーマ）を生成し、LLM からのツールコールを受け取ってペイロードをデコード・検証します。カタログ型パラメータにより、許可するコンポーネント集合をコンパイル時に束縛します。ペイロードに問題がある場合はツールエラーを返し、LLM が同一ターン内で自己修正できるサイクルを実現します。

`A2UIToolResultExtractor` はツール結果から `ServerMessage` を取り出すユーティリティです。オーケストレーター側がエージェントのレスポンスを受け取る際に使用します。

```swift
import A2UIAgentTool
import A2UITyped
import LLMClient

// BasicCatalog に限定したツールを LLM に登録する
let tool = SendA2UIToClientTool<BasicCatalog>(
    examples: [],
    promptBuilder: A2UIPromptBuilder(
        serverToClientSchema: nil,
        commonTypesSchema: nil,
        catalogSchema: nil,
        allowedComponents: BasicComponent.componentNames,
        allowedMessages: nil
    )
)
let tools: [any Tool] = [tool]
```

## Topics

### ツール定義

- ``SendA2UIToClientTool``

### ツール結果処理

- ``A2UIToolResultExtractor``
