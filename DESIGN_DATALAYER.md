# swift-a2ui Data Layer 設計ドキュメント（v0.9 準拠 / 実装前レビュー用）

作成日: 2026-05-28
ステータス: **Data Layer 全 6 Step 実装完了（2026-05-28）**

## 実装状況（feature/data-layer ブランチ）
- ✅ Step 1: DataModel（相対パス / auto-viv / 型強制 / cascade·bubble 通知 / 購読）— A2UISurface
- ✅ Step 2: DataContext / ComponentContext（resolve / subscribe / nested）— A2UIRuntime
- ✅ Step 3: 関数 / checks 評価（formatString 中心、全14関数）— A2UIRuntime
- ✅ Step 4: @Observable 状態モデル + MessageProcessor（ライフサイクル）— A2UISurface
- ✅ Step 5: template List 展開（ResolvedChild / scope）— A2UIRuntime
- ✅ Step 6: Binder Layer（ResolvedComponent = @Observable 解決済み props）— A2UIRuntime

全 260 テスト通過。SwiftUI View 実装は責務境界どおり利用者（Delish）側。
次：delish-ios の Phase 1（runA2UIAgent 置換）/ Phase 2（この Data Layer の上に SwiftUI View）。

## 合意事項（2026-05-28）
1. ターゲット分割: **`A2UIRuntime` を新設**（DataContext / 関数評価 / Binder）。`A2UISurface` に DataModel/通知/MessageProcessor を集約。
2. 状態モデル: **`@Observable` 参照型 `SurfaceModel`/`ComponentModel` に寄せる**。`SurfaceStore`(actor) はスナップショット/集約用に再位置付け。
3. 追加先: **no-problem `swift-a2ui` 本体**（最初から本体に実装、汎用ライブラリとして育てる）。
4. 公式テストケース: **リポに同梱コピー**（`Tests/` 下に fixture を置く）。
対象: `swift-a2ui`（no-problem A2UI Swift パッケージ）

---

## 0. 目的とスコープ

A2UI v0.9 公式仕様（`google/A2UI` の `specification/v0_9/docs/renderer_guide.md` §3）が
「クライアント必須」と規定する **Framework-Agnostic Data Layer** を `swift-a2ui` に実装する。

現状の `swift-a2ui` は headless だが、仕様が必須とする Data Layer の大半が欠落している
（JSON Pointer の resolve/set/remove のみ。binding 解決・template 展開・関数評価・リアクティブ通知が無い）。
本設計はこの欠落を埋め、**利用者が SwiftUI View を書くための土台（Binder）まで**を提供する。

### 責務境界（確定事項）

| | swift-a2ui（ライブラリ） | 利用者（Delish 等） |
|---|---|---|
| DataModel（pointer/相対/cascade/bubble/型強制/auto-viv/購読） | ✅ | — |
| DataContext / ComponentContext（resolve/subscribe/nested） | ✅ | — |
| template List 展開 | ✅ | — |
| 関数 / checks 評価（formatString 等のロジック、SwiftUI 非依存） | ✅ | — |
| SurfaceModel / ComponentModel / MessageProcessor（ライフサイクル） | ✅ | — |
| **Binder Layer**（Dynamic* → 解決済み `@Observable` ResolvedProps） | ✅（利用者が View を書く土台） | — |
| **SwiftUI View 実装（Basic Catalog 17種 + custom）** | ❌ | ✅ すべて |
| Surface ツリー再帰描画（SwiftUI） | ❌ | ✅ |

**理由:** 「スタイルを差し込めるだけの汎用 View」は SwiftUI の柔軟性（ViewModifier / @ViewBuilder /
環境値 / レイアウト）の前では利用価値が低く、利用者は結局描き直す → 汎用 View 層は負債になる。
ライブラリは「解決済みの値とアクションのストリーム（ResolvedProps）」を Binder で保証するところまでを責務とし、
ピクセル描画は利用者に完全に委ねる（仕様 §7「差し替え可能性」とも整合）。

---

## 1. 依存ライブラリの選定（仕様 §9.2 が明示を要求）

- **Schema Library**: 不使用。既存の `Codable` struct / enum（`A2UICore` の型）をそのまま使う。
  仕様も「If no suitable library exists, raw JSON Schema strings or `Codable` structs can be used」と許容。
- **Observable / Reactive Library**:
  - **Stateful Stream（Signal 的）**: `@Observable`（Swift Observation, iOS17+）を採用。SurfaceModel /
    ComponentModel / ResolvedProps を `@Observable` にし、SwiftUI から直接購読 → 自動再描画。
  - **Path 単位の購読（DataModel の cascade/bubble）**: `@Observable` だけでは「特定 path の購読 + dispose」は
    表現できないため、**独自の軽量 Subscription 機構**（`A2UISubscription` + dispose）を別途実装する。
    仕様の要求「初期値を同期で返し、変更を通知、unsubscribe 可能」を満たす最小実装。
  - **Event Stream（discrete: onSurfaceCreated / onAction）**: 独自の `EventSource<T>`（multicast + unsubscribe）。
  - **不採用**: Combine（iOS バージョン/Sendable 取り回しと将来の非 Apple 展開を考慮）、AsyncStream
    （「初期値を同期で返す」signal 要件と相性が悪い）。

> この選定は仕様 §3 の Observable 要件（Event Stream と Stateful Stream の両方、unsubscribe 必須）を満たす。

---

## 2. ターゲット構成

既存の headless 分割思想を維持し、**Data Layer の binding/関数/通知を `A2UISurface` に集約拡張**、
**Binder と DataContext を新規ターゲット `A2UIRuntime`** に切り出す。SwiftUI View はライブラリに含めない
（利用者責務）。

```
swift-a2ui/Sources/
  A2UICore       (既存: 型。DynamicValue/DynamicString/CheckRule/Action/...)
  A2UICatalog    (既存: ComponentCatalog / BasicComponent / catalog.json)
  A2UIParser     (既存: block / streaming parser)
  A2UIPrompt     (既存: prompt builder + schema resources)
  A2UISurface    (拡張: DataModel / 通知 / MessageProcessor ライフサイクル / template 展開)
  A2UIRuntime    (新規: DataContext / ComponentContext / 関数評価 / Binder / ResolvedProps)
```

**`A2UIRuntime` を分ける理由:** Binder と関数評価は「dataModel に対する解決ロジック」であり、
状態保持（Surface）とは別の関心事。利用者は `A2UIRuntime` の Binder を import して View を書く。
SwiftUI 依存はゼロに保つ（利用者の SwiftUI 層が `A2UIRuntime` の上に乗る）。

> 代替案: すべて `A2UISurface` に集約（ターゲットを増やさない）。
> → binding/関数の規模が大きく、関心事も別なので分離を推奨。レビューで合意したい点①。

---

## 3. Data Layer の型設計

### 3.1 DataModel（`A2UISurface`、`@Observable` ではなく独自通知を持つ参照型）

仕様 §3「DataModel」+「JSON Pointer Implementation Rules」+「Type Coercion Standards」を実装。

```swift
public final class DataModel: @unchecked Sendable {
    // 内部状態は AnyCodable ツリー。
    public func get(_ path: String) -> AnyCodable?            // 絶対 / 相対パス両対応
    public func set(_ path: String, _ value: AnyCodable?)     // auto-viv + undefined 削除
    public func subscribe(_ path: String,
                          _ onChange: @escaping (AnyCodable?) -> Void) -> A2UISubscription
    // 初期値を同期で onChange(現在値) してから購読を張る（signal 要件）
}
```

実装する仕様要件（**各々テストで固定する**）:
1. **相対パス**: `/` 始まりは絶対、それ以外は呼び出し側スコープからの相対（template 用、RFC6901 拡張）。
   → `JSONPointer` に baseScope 付き resolve を追加。
2. **Auto-vivification**: `/a/b/0/c` で set 時、中間を生成。**次トークンが数値なら Array、そうでなければ Object**。
   → 現 `JSONPointer.setRecursive` は常に object 化するので **要修正**。
3. **Notification（Bubble & Cascade）**: 変更 path の完全一致 + 親へ bubble + 子孫へ cascade、全該当購読者に通知。
4. **Undefined Handling**: object key は削除。array index は length 保持で空（sparse）。
5. **Type Coercion**（仕様の表をそのまま実装）: String↔Bool↔Number↔String の規則。

### 3.2 SurfaceModel / ComponentModel / SurfaceComponentsModel（`A2UISurface`、`@Observable`）

仕様 §3「State Models」。`@Observable` にして SwiftUI から購読可能にする。

```swift
@Observable public final class SurfaceModel {
    public let id: String
    public let catalogId: String
    public let theme: AnyCodable?
    public let sendDataModel: Bool
    public let dataModel: DataModel
    public let components: SurfaceComponentsModel
    public let onAction: EventSource<A2UIClientAction>
    public func dispatchAction(_ payload: [String: AnyCodable], sourceComponentId: String)
}

@Observable public final class SurfaceComponentsModel {
    public func get(_ id: String) -> ComponentModel?
    public func add(_ component: ComponentModel)
    public let onCreated: EventSource<ComponentModel>
    public let onDeleted: EventSource<String>
}

@Observable public final class ComponentModel {
    public let id: String
    public let type: String          // "Button" 等
    public var properties: [String: AnyCodable]   // 変更で onUpdated
    public let onUpdated: EventSource<ComponentModel>
}
```

> 既存の値型 `SurfaceState` は MessageProcessor の内部/スナップショット用途として残すか統合するかを
> レビューで決めたい点②（`@Observable` 参照型へ寄せる方針を推奨）。

### 3.3 MessageProcessor（`A2UISurface`、ライフサイクル規約を仕様準拠に）

既存 `SurfaceCoordinator` を仕様 §3「Processing Layer」に合わせて拡張 or 改名。
- ✅ 既存: 重複 createSurface はエラー。
- ➕ 追加: **同 id で type 違いの updateComponents は旧 component を破棄して作り直す**（仕様明記、未実装）。
- ➕ 追加: `getClientDataModel()`（sendDataModel=true の surface を集約。transport が action 送信時に使う）。

### 3.4 DataContext / ComponentContext（`A2UIRuntime`）

仕様 §3「The Context Layer」。

```swift
public struct DataContext {
    public let path: String                       // 現在のスコープ
    public func resolveDynamicValue(_ v: DynamicValue) -> AnyCodable?
    public func resolveDynamicString(_ s: DynamicString) -> String?
    public func subscribeDynamicValue(_ v: DynamicValue,
                                      _ onChange: @escaping (AnyCodable?) -> Void) -> A2UISubscription
    public func nested(_ relativePath: String) -> DataContext     // template の子スコープ
    public func set(_ path: String, _ value: AnyCodable?)
}

public struct ComponentContext {
    public let componentModel: ComponentModel
    public let dataContext: DataContext
    public let surfaceComponents: SurfaceComponentsModel   // escape hatch
    public func dispatchAction(_ action: [String: AnyCodable])
}
```

### 3.5 関数 / checks 評価（`A2UIRuntime`）

仕様 §7。`FunctionImplementation` プロトコル + Basic Catalog の関数群。

```swift
public protocol FunctionImplementation: Sendable {
    var name: String { get }
    var returnType: FunctionReturnType { get }
    func execute(args: [String: AnyCodable], context: DataContext) -> AnyCodable?
}
```

- 実装: `required` `regex` `email` `length` `numeric` `formatString` `formatNumber`
  `formatCurrency` `formatDate` `pluralize` `and` `or` `not` `openUrl`。
- **重要（仕様 §9.7）**: 文字列補間は **`formatString` の中だけ**。全文字列にグローバル補間を足さない。
- `formatString`: `${...}` のトークン化（DataPath vs FunctionCall）、再帰/ネスト、`\${` エスケープ、
  結果の型強制（§ Type Coercion）。
- **checks**: `CheckRule.condition`（DynamicBoolean）を評価。失敗で message を返す。Button の checks 失敗は
  「無効化」を Binder の ResolvedProps に反映（`isEnabled: false` + `validationMessage`）。

### 3.6 template List 展開（`A2UISurface` or `A2UIRuntime`）

仕様 §「Collection scopes」。`ChildList.template(componentId, path)` のとき:
- `path` の配列を反復 → item ごとに `DataContext.nested("/<path>/<index>")` を作り、
  テンプレート component を実体化。相対パスが `/path/N/...` に解決される。
- 配列以外（dictionary）の扱いも vendored を参考に決める（キーソートで反復）。

### 3.7 Binder Layer（`A2UIRuntime`、利用者 View の土台 = 最重要 API）

仕様 §5 Strategy 2「Binder Layer Pattern」。

```swift
@Observable public final class ResolvedProps<P> { public private(set) var value: P /* ... */ }

public protocol ComponentBinder {
    associatedtype Props
    func bind(_ context: ComponentContext) -> ComponentBinding<Props>
}

public final class ComponentBinding<Props> {
    public let props: ResolvedProps<Props>   // @Observable: 利用者 View はこれを購読
    public func dispose()                    // 全 path 購読を解除
}
```

- Data Props（label/value 等）: Binder が DynamicValue を解決して **解決済みの静的値**として props に載せる。
  dataModel 変化で `props.value` を更新 → SwiftUI が自動再描画。
- Structural Props（child/children）: Binder は **解決しない**。`{ id, basePath }` のメタだけ出力。
  利用者の View が `buildChild(id, basePath)` で再帰描画（scope path を伝播）。
- mount で `bind`、unmount で `dispose`（購読リーク防止、仕様 §6）。

---

## 4. TDD ビルド順序（renderer_guide.md §9 準拠。各 step で `swift test` グリーンをゲートに）

| Step | 実装 | テスト（fixture は `../google-a2ui/specification/v0_9/test/cases/` と `json/.../examples/` を取り込む） |
|---|---|---|
| **1** | DataModel（相対パス・auto-viv 修正・型強制・cascade/bubble 通知・購読/dispose） | pointer 解決（絶対/相対）、numeric auto-viv→Array、型強制表、bubble/cascade 通知、undefined 削除、subscribe の初期同期発火 |
| **2** | DataContext / ComponentContext（resolve/subscribe/nested） | 仕様の scope 例（template 内 `name` → `/employees/0/name`、`/company` は絶対）を固定 |
| **3** | 関数 / checks 評価（formatString 中心） | 各関数の単体、formatString の再帰/ネスト/エスケープ、checks 失敗→message。pluralize は ICU |
| **4** | SurfaceModel/ComponentModel/MessageProcessor（ライフサイクル + getClientDataModel） | 重複 createSurface エラー、同 id type 違いの作り直し、sendDataModel 集約 |
| **5** | template List 展開 | 配列バインドで N 行生成、各行の scope path、空配列/欠損 path の graceful |
| **6** | Binder Layer（ResolvedProps @Observable） | Data Props 解決値の反映、dataModel 変化での props 更新、Structural Props のメタ出力、dispose で購読解除 |

> Step 1〜3 が「データバインディング周り」の核心。ここが緑になれば、利用者は Binder（Step 6）の上に
> SwiftUI を自由に書ける。

---

## 5. レビューで合意したい点

1. **ターゲット分割**: `A2UIRuntime` を新設 vs `A2UISurface` に集約（本設計は新設を推奨）。
2. **状態モデル**: 既存値型 `SurfaceState` を `@Observable` 参照型 `SurfaceModel` に寄せる方針で良いか
   （既存 `SurfaceStore`/`SurfaceCoordinator` の actor 設計との整合）。
3. **公式テストケースの取り込み方**: fixture をリポジトリに同梱 vs サブモジュール/スクリプト取得。
4. **上流還元**: この Data Layer を no-problem `swift-a2ui` 本体に入れる前提で良いか
   （Delish 内製 → 後で還元、ではなく最初から本体に入れる）。

---

## 6. 参照

- 仕様: `../google-a2ui/specification/v0_9/docs/{a2ui_protocol,renderer_guide,basic_catalog_implementation_guide}.md`
- 公式テスト: `../google-a2ui/specification/v0_9/test/cases/`、`../google-a2ui/specification/v0_9/json/catalogs/{minimal,basic}/examples/`
- 検算用参考（コピー元ではない）: delish-ios の vendored `A2UISwiftCore`（`DataContext`/`GenericBinder`/`BasicFunctions`/`MessageProcessor`）
