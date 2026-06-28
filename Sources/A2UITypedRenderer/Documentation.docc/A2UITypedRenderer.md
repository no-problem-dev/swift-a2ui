# ``A2UITypedRenderer``

`A2UICatalog` 上の型安全な SwiftUI レンダラー — `AnyView` を一切使わずにコンポーネントツリーを描画する。

## Overview

`A2UITypedRenderer` は `A2UITyped` のジェネリックカタログ型の上に、ゼロ型消去の SwiftUI レンダラーを構築する。`AnyView` を排除したジェネリックな `NodeView<Catalog>` が再帰的にコンポーネントツリーを走査し、各ノードを対応する SwiftUI ビューに変換する。

`RenderableCatalog` プロトコルは `A2UICatalog` に加えて `render` 要件を追加する。カタログ型がこのプロトコルに準拠することで、`A2UISurfaceView<Catalog>` がそのカタログのコンポーネントを自動的にディスパッチして描画できる。`RenderContext<Catalog>` はレンダリング中に必要な状態（データモデル・イベントハンドラ・テーマ）を保持する。

`TypedMessageProcessor<Catalog>` は LLM から届く `ServerMessage` を受け取り、`TypedSurface<Catalog>` の状態を更新する。`TypedSurface<Catalog>` は `@Observable` として SwiftUI に公開されるサーフェスの実体。`BasicComponentView<Catalog>` は `BasicEmbeddingNode` が埋め込まれた標準コンポーネントすべての SwiftUI 描画を担う。

```swift
import SwiftUI
import A2UITypedRenderer
import A2UITyped

// BasicCatalog ベースのサーフェスを管理・描画する
struct ContentView: View {
    // TypedSurface は @Observable なので @State で保持する
    @State private var surface = TypedSurface<BasicCatalog>(nodes: [])

    var body: some View {
        // A2UISurfaceView はラベルなしの第1引数でサーフェスを受け取る
        A2UISurfaceView(surface)
    }
}

// サーバーメッセージを適用する（TypedMessageProcessor を使う場合）
@MainActor
func apply(_ messages: [ServerMessage], to processor: TypedMessageProcessor<BasicCatalog>) {
    processor.process(messages)
}
```

## Topics

### エントリポイントビュー

- ``A2UISurfaceView``
- ``NodeView``
- ``BasicComponentView``

### レンダリングコンテキスト

- ``RenderableCatalog``
- ``RenderContext``

### サーフェス状態管理

- ``TypedSurface``
- ``TypedMessageProcessor``
