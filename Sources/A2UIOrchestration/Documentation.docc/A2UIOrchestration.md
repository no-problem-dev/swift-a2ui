# ``A2UIOrchestration``

マルチエージェント編成のオーケストレーションポリシー — サーフェス所有権台帳・決定論的ルーティング・データモデル絞り込みを提供する。

## Overview

`A2UIOrchestration` はマルチエージェント構成における A2UI サーフェスの所有権管理とメッセージルーティングを担います。Python SDK の公式オーケストレータサンプルに対応し、UI・LLM ランタイムへの依存を持たない純粋関数の集合として実装されています。

`SurfaceOwnership` はサーフェス ID とエージェント名の対応を追跡する会話スコープの台帳です。主に 3 つの用途で使います。**記録**（`record(surfacesCreatedIn:by:)`）はサブエージェントのレスポンスを観察してサーフェスの所有者を登録します。**決定論的ルーティング**（`owner(ofUserActionIn:)`）は `UserAction` の `surfaceId` から所有エージェントを即座に特定し、LLM ルーティングを回避します。**データモデル絞り込み**（`outboundMetadata(_:capabilities:for:)`）はエージェントに送るメタデータを自分のサーフェス分だけに絞り込み、他エージェントのデータを漏洩させません。

ホストランタイムはこれらをフックとして自分のセッション管理コードに組み込みます。`SurfaceOwnership` 自体は値型であり、ホストのセッション状態として保持・更新します。

```swift
import A2UIOrchestration
import A2UIA2A
import A2ACore

var ownership = SurfaceOwnership()

// サブエージェントの返答を受け取ったとき
ownership.record(surfacesCreatedIn: responseParts, by: "a2ui")

// 次のユーザーメッセージのルーティング
if let agent = ownership.owner(ofUserActionIn: userParts) {
    // LLM を経由せずに直接ルーティング
    await sendTo(agent: agent, parts: userParts)
}

// サブエージェントへ送るメタデータを絞り込む
let outgoing = try ownership.outboundMetadata(
    metadata, capabilities: caps, for: "a2ui"
)
```

## Topics

### サーフェス所有権管理

- ``SurfaceOwnership``
