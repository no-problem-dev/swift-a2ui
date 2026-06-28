# ``A2UITypedRenderer``

`A2UICatalog` 上の型安全な SwiftUI レンダラー — `AnyView` を一切使わずにコンポーネントツリーを描画する。

## Overview

`A2UITypedRenderer` は `A2UITyped` のジェネリックカタログ型の上に、ゼロ型消去の SwiftUI レンダラーを構築します。`AnyView` を排除したジェネリックな `NodeView<Catalog>` が再帰的にコンポーネントツリーを走査し、各ノードを対応する SwiftUI ビューに変換します。

`RenderableCatalog` プロトコルは `A2UICatalog` に加えて `render` 要件を追加します。カタログ型がこのプロトコルに準拠することで、`A2UISurfaceView<Catalog>` がそのカタログのコンポーネントを自動的にディスパッチして描画できます。`RenderContext<Catalog>` はレンダリング中に必要な状態（データモデル・イベントハンドラ・テーマ）を保持します。

`TypedMessageProcessor<Catalog>` は LLM から届く `ServerMessage` を受け取り、`TypedSurface<Catalog>` の状態を更新します。`TypedSurface<Catalog>` は `ObservableObject` として SwiftUI に公開されるサーフェスの実体です。`BasicComponentView<Catalog>` は `BasicEmbeddingNode` が埋め込まれた標準コンポーネントすべての SwiftUI 描画を担います。

```swift
import A2UITypedRenderer
import A2UITyped

// BasicCatalog ベースのサーフェスビューを表示する
struct ContentView: View {
    @StateObject private var surface = TypedSurface<BasicCatalog>()

    var body: some View {
        A2UISurfaceView(surface: surface)
            .onReceive(messageStream) { message in
                TypedMessageProcessor<BasicCatalog>().process(message, into: surface)
            }
    }
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
