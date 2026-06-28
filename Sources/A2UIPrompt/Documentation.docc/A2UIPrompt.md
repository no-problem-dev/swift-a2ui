# ``A2UIPrompt``

LLM エージェント向け A2UI システムプロンプトをコンポーザブルに組み立てるモジュール。

## Overview

`A2UIPrompt` は A2UI エージェントに渡すシステムプロンプトを構造化されたビルダーパターンで生成する。プロンプトの各セクション（役割・ワークフロー規則・UI 規則・スキーマブロック・使用例）は独立したコンポーネントとして保持され、`A2UIPromptBuilder` が最終的な文字列に合成する。

`SchemaPruner` は許可されたコンポーネント集合を受け取り、フルスキーマから不要なエントリを削除してプロンプトのトークン数を削減する。`SchemaBlockFormatter` は削減済みスキーマを LLM が読みやすいテキストブロックに変換する。`A2UIExample` は標準的なサーフェス使用例の文字列を提供し、`A2UIExampleFormatter` がそれをプロンプト内の名前付きブロックとして整形する。

`A2UIWorkflowRules` はツールコールの発行規則・スコープルール・カタログ規則・数式テキスト規則など、エージェントが守るべき手順を静的文字列として公開する。`A2UIPresenterAgent`（`A2UIAgent` モジュール）はこれらを組み合わせてプレゼンターエージェントの完全なシステムプロンプトを生成する。

```swift
import A2UIPrompt
import A2UICatalog

// カスタムコンポーネントセットに絞り込んだプロンプトを生成する
let builder = A2UIPromptBuilder(
    serverToClientSchema: nil,
    commonTypesSchema: nil,
    catalogSchema: nil,
    allowedComponents: ["text", "button", "column"],
    allowedMessages: ["createSurface", "updateDataModel"]
)
let prompt = builder.buildSystemPrompt(
    role: "You are an A2UI agent.",
    workflowRules: A2UIWorkflowRules.toolCall,
    uiDescription: "Use a column as the root.",
    includeSchema: true
)
```

## Topics

### プロンプトビルダー

- ``A2UIPromptBuilder``

### スキーマ処理

- ``SchemaPruner``
- ``SchemaBlockFormatter``

### 使用例

- ``A2UIExample``
- ``A2UIExampleFormatter``

### ワークフロー規則

- ``A2UIWorkflowRules``
