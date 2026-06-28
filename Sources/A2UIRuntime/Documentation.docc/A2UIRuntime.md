# ``A2UIRuntime``

テンプレート展開・関数評価・条件チェックを担うサーフェス実行エンジン。

## Overview

`A2UIRuntime` は `A2UISurface` が保持するコンポーネントツリーとデータモデルを元に、テンプレートの展開・組み込み関数の評価・条件規則のチェックを実行する。SwiftUI には依存せず、ロジック層として独立してテストできる。

`TemplateExpander` はリストコンポーネントなどのデータ駆動繰り返しを、データモデルのコレクションに基づいて実際のノード列に展開する。各展開済みノードは `ResolvedChild` として返され、`componentId` と `basePath` を保持する。

`FunctionResolving` プロトコルは `callFunction` アクション発生時に呼び出す関数の解決インターフェースを定義する。`BasicFunctions` はビルトイン関数の実装を提供する。関数が存在しない場合は `NoFunctionResolver` を差し込むことで無害な no-op にできる。`ChecksEvaluator` は `CheckRule` の配列を評価し、バリデーション結果（エラーメッセージ・有効フラグ）を返す。

```swift
import A2UIRuntime
import A2UISurface

// ビルトイン関数リゾルバーを使ってデータコンテキストを構築する
let resolver = BasicFunctions()
let context = DataContext(dataModel: DataModel(), functions: resolver)

// ChildList をテンプレート展開する
let children = TemplateExpander.expand(listNode, in: context)
for child in children {
    print(child.componentId, child.basePath)
}
```

## Topics

### テンプレート展開

- ``TemplateExpander``
- ``ResolvedChild``
- ``DataContext``

### 関数評価

- ``FunctionResolving``
- ``BasicFunctions``
- ``NoFunctionResolver``

### 条件チェック

- ``ChecksEvaluator``
