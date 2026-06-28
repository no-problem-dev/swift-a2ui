# ``A2UISurface``

コンポーネントツリーとデータモデルを管理し、バインディング解決・バリデーションを提供するサーフェス層。

## Overview

`A2UISurface` は A2UI サーフェスのランタイム状態を保持する。コンポーネントのツリー構造（`ComponentNode`）、JSONPointer でアドレス指定されたデータモデル（`DataModel`）、そしてデータモデルの変更を購読する仕組み（`A2UISubscription`）が中心的な要素。

`DataModel` はサーフェス全体のデータを保持する mutable なクラス。`DynamicString`・`DynamicBoolean` などのバインディング値はこのモデルの対応パスから実行時に読み取られる。`TypeCoercion` はパスから取得した動的値を Swift の具体型へ変換する。

`ComponentTreeResolver` はコンポーネントの階層ツリーをフラットなノードマップに解決し、レンダラーが高速にルックアップできる形式に変換する。`ComponentValidator` は `ServerMessage` として受信したペイロードの内容（参照されているバインディングパスが存在するかなど）を検証する。`JSONPointer` は RFC 6901 準拠の JSON Pointer 解析と評価を提供し、データモデルの特定パスへのアクセスを担う。

```swift
import A2UISurface

// データモデルを作成してパスに値を書き込む
let model = DataModel()
model.set("/greeting", .string("こんにちは"))

// JSON Pointer でパスを読み取る
let value = model.get("/greeting")   // .string("こんにちは")
```

## Topics

### コンポーネントツリー

- ``ComponentNode``
- ``ComponentTreeResolver``

### データモデル

- ``DataModel``
- ``A2UISubscription``
- ``TypeCoercion``
- ``JSONPointer``

### バリデーション

- ``ComponentValidator``
