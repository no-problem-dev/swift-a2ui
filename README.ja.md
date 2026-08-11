[English](./README.md) | 日本語

# swift-a2ui

LLM エージェントの答えを、文字の壁ではなくタップできる SwiftUI の画面（カード・フォーム・ボタン）として返し、アプリが実際に描けるコンポーネントの範囲にモデルを縛る。

> **非公式。** A2UI プロトコルの作者とは何の関係もなく、承認も受けていない。仕様に準拠することはこのプロジェクトの目標ではない。

## 概要

[A2UI](https://a2ui.org) では、エージェントが UI サーフェスを生成・更新・削除する JSON メッセージを送り、
クライアントがそれを描画してユーザーの操作を返す。このパッケージはその両側を Swift で持つ。

- **パレットは Swift の型。** モデルに渡す JSON Schema をその型から生成するので、
  「モデルに描いてよいと伝えたもの」と「レンダラーが描き方を知っているもの」がずれない。
- **プロンプトと検証が同じ allowlist を共有する。** 6 種を許可すればモデルに渡るスキーマも 6 種。
  それ以外はツールがエラーで突き返し、モデルは同じターン内で自己修正する。
  ユーザーが未対応コンポーネントのプレースホルダーを見ることがない。
- **`AnyView` なし・文字列照合なし。** `A2UISurfaceView<Catalog>` はカタログに対してジェネリックなので、
  独自コンポーネントの追加は型レベルの拡張になり、網羅性はコンパイラが検査する。
- **モデルの出力は汚れている、という前提で作ってある。** ストリーミングされるテキストは届いた分から
  逐次パースし、LLM がよく出す壊れ方は捨てずに修復する。
- **1 つの画面を複数のエージェントで使える。** 所有台帳がユーザー操作をそのサーフェスを描いた
  エージェントへ差し戻し、あるエージェントのデータモデルを別のエージェントのメッセージから外す。

## 使い方

エージェントが送ってきたものを描画する。サーフェスは `TypedMessageProcessor` が保持し、
`A2UISurfaceView` が描く。

```swift
import SwiftUI
import A2UIParser
import A2UITyped
import A2UITypedRenderer

struct AgentReply: View {
    @State private var processor = TypedMessageProcessor<BasicCatalog>()
    private let parser = A2UIStreamingParser()

    var body: some View {
        ForEach(processor.ordered) { surface in
            A2UISurfaceView(surface)
        }
    }

    func receive(_ chunk: String) {
        for part in parser.feed(chunk) {
            if let messages = part.messages {
                processor.process(messages)
            }
        }
    }
}
```

エージェント側は `A2UIPresenterAgent` がプロンプト・ツール・カード拡張を自分で持つので、
ホストが選ぶのは言語とパレットだけ。

```swift
import A2UIAgent

let prompt = A2UIPresenterAgent.systemPrompt(language: "Japanese")
let tools = A2UIPresenterAgent.tools(
    components: ["Column", "Row", "Text", "Image", "Card", "Button"]
)
```

## ドキュメント

[全モジュールの API リファレンス](https://no-problem-dev.github.io/swift-a2ui/documentation/a2uicore/)。
独自コンポーネントのカタログを組む手順もここにある。

## インストール

`Package.swift` に追加する。

```swift
.package(url: "https://github.com/no-problem-dev/swift-a2ui.git", .upToNextMinor(from: "0.25.0")),
```

モジュールごとに library を分けてあるので、使うものだけに依存すればよい。
メッセージ型は `A2UICore`、描画は `A2UITypedRenderer`、出来合いの presenter エージェントは `A2UIAgent`。

```swift
.target(name: "MyApp", dependencies: [
    .product(name: "A2UICore", package: "swift-a2ui"),
    .product(name: "A2UITypedRenderer", package: "swift-a2ui"),
    .product(name: "A2UIAgent", package: "swift-a2ui"),
])
```

## 動作要件

| | |
|---|---|
| Swift | 6.2 |
| プラットフォーム | iOS 17 · macOS 14 |

## コントリビューション

バグ報告・プルリクエスト歓迎。[CONTRIBUTING.md](./CONTRIBUTING.md) を参照。

## ライセンス

MIT。[LICENSE](./LICENSE) を参照。
