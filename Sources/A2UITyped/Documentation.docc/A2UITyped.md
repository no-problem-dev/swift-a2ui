# ``A2UITyped``

コンパイル時型安全なコンポーネントノードとカタログ抽象を提供するジェネリックカタログ層。

## Overview

`A2UITyped` は A2UI の stringly-typed なコンポーネントディスパッチをコンパイル時型安全な設計に置き換えます。SwiftUI への依存がなく、macOS でも完全にビルドできるため、型レベルのイテレーションやテストをランナブルとして素早く実行できます。

`A2UICatalog` プロトコルはカタログの関連型（`Node` = デコード対象の `ComponentNode`）と `catalogId` を定義します。`ComponentNode` プロトコルは個々のコンポーネント型の共通インターフェースで、`Decodable`・`Sendable`・`Equatable` に準拠します。`CatalogNode<Known>` はジェネリックな列挙型で、既知のコンポーネント（`.known(Known)`）と未知コンポーネント（`.unknown(String, Data)`）の両方を型安全に扱います。

`BasicCatalog` は `A2UICatalog` の具体実装で、`A2UICatalog` の標準コンポーネント 19 種すべてを `BasicNode` として統合します。`CombinedNode<Primary, Fallback>` は 2 つのカタログノードを合成し、カタログ拡張を容易にします。`A2UIValidation` はデコード済みノードの整合性検証を担います。

```swift
import A2UITyped

// BasicCatalog を使ってサーバーメッセージをデコードする
let data: Data = ... // JSON ペイロード
let node = try JSONDecoder().decode(CatalogNode<BasicCatalog.Node>.self, from: data)
switch node {
case .known(let known):
    print("既知コンポーネント:", known)
case .unknown(let type, _):
    print("未知コンポーネント:", type)
}
```

## Topics

### カタログプロトコル

- ``A2UICatalog``
- ``ComponentNode``

### 標準カタログ

- ``BasicCatalog``
- ``BasicEmbeddingNode``

### ジェネリックノード

- ``CatalogNode``
- ``CombinedNode``

### バリデーション

- ``A2UIValidation``
