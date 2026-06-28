# ``A2UITyped``

コンパイル時型安全なコンポーネントノードとカタログ抽象を提供するジェネリックカタログ層。

## Overview

`A2UITyped` は A2UI の stringly-typed なコンポーネントディスパッチをコンパイル時型安全な設計に置き換える。SwiftUI への依存がなく、macOS でも完全にビルドできるため、型レベルのイテレーションやテストをランナブルとして素早く実行できる。

`A2UICatalog` プロトコルはカタログの関連型（`Node` = デコード対象の `ComponentNode`）と `catalogId` を定義する。`ComponentNode` プロトコルは個々のコンポーネント型の共通インターフェースで、`Decodable`・`Sendable`・`Equatable` に準拠する。`CatalogNode<Known>` はジェネリックな列挙型で、既知のコンポーネント（`.known(Known)`）と未知コンポーネント（`.unknown(name: String, id: ComponentId, raw: StructuredValue)`）の両方を型安全に扱う。

`BasicCatalog` は `A2UICatalog` の具体実装で、標準コンポーネント 18 種すべてを `BasicComponent` として統合する。`CombinedNode<Primary, Fallback>` は 2 つのカタログノードを合成し、カタログ拡張を容易にする。`A2UIValidation` はデコード済みノードの整合性検証を担う。

```swift
import A2UITyped

// BasicCatalog を使ってサーバーメッセージをデコードする
let data: Data = ... // JSON ペイロード
let node = try JSONDecoder().decode(CatalogNode<BasicComponent>.self, from: data)
switch node {
case .known(let known):
    print("既知コンポーネント:", known)
case .unknown(let name, _, _):
    print("未知コンポーネント:", name)
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
