# ``A2UIAgent``

プレゼンター型 A2UI エージェントの役割・ツール・プロトコル宣言を一元管理する自己記述モジュール。

## Overview

`A2UIAgent` は A2UI のプレゼンター（コンテンツ提示）エージェントを動かすために必要なすべての知識を 1 つのモジュールに集約する。Python SDK の `a2ui.adk` と `rizzcharts` パターンに対応する Swift 実装。

`A2UIPresenterAgent` 名前空間がこのモジュールのすべてを公開する。`systemPrompt(language:)` は役割定義・UI 規則・ワークフロー規則を合成した完全なシステムプロンプトを生成する。`tools(components:)` は許可コンポーネントセットに絞り込んだ `SendA2UIToClientTool` を返す。スキーマと使用例はツールが所有し、アタッチ時にシステムプロンプトへ自動で同伴する（公式 rizzcharts 準拠）。`agentExtension()` は A2A の AgentCard に埋め込む A2UI 対応宣言を返す。

ホストアプリはこれらを executor に注入するだけでよく、UI ドメインの知識をアプリ側に持つ必要がない。言語・モデル・コンポーネントパレットの選択だけがホストの判断領域。

```swift
import A2UIAgent

// エグゼキューターへの注入例
let systemPrompt = A2UIPresenterAgent.systemPrompt(language: "Japanese")
let tools = A2UIPresenterAgent.tools(
    components: A2UIPresenterAgent.defaultComponents
)
let ext = A2UIPresenterAgent.agentExtension()

// ホスト出力制約の追加
let constraint = A2UIPresenterAgent.hostOutputConstraint(agentName: "a2ui")
```

## Topics

### エージェント自己記述

- ``A2UIPresenterAgent``
