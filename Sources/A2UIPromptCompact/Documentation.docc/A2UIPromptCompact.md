# ``A2UIPromptCompact``

共通型の重複記述を圧縮してシステムプロンプトのトークン数を削減するコンパクトビルダー。

## Overview

`A2UIPromptCompact` は `A2UIPrompt` を補完するモジュール。LLM のコンテキストウィンドウが限られた状況や、多くのコンポーネントを使うときにプロンプトのトークン数が膨らむ問題を解消する。

`CommonTypesCompactor` は `DynamicString`・`DynamicBoolean`・`DataBinding` などの共通型を一度だけ定義する短縮表現に変換し、各コンポーネントスキーマから重複する型定義を除去する。`A2UIPromptCompactBuilder` は `A2UIPromptBuilder` と同じ API を持ちながら、この圧縮処理を内部で適用する。同じコンポーネントセットでも圧縮版はフル版より大幅に短いプロンプトを生成し、コンテキスト消費を抑えながら同等の情報を LLM に伝えられる。

```swift
import A2UIPromptCompact
import A2UICatalog

// 圧縮版ビルダーでシステムプロンプトを生成する
let builder = A2UIPromptCompactBuilder(
    allowedComponents: BasicComponent.componentNames,
    allowedMessages: nil
)
let compactPrompt = builder.buildSystemPrompt(
    role: "You are an A2UI agent.",
    workflowRules: "",
    uiDescription: "",
    includeSchema: true
)
```

## Topics

### 圧縮ビルダー

- ``A2UIPromptCompactBuilder``

### 共通型圧縮

- ``CommonTypesCompactor``
