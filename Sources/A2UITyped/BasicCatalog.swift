import A2UICore
import A2UICatalog

/// `BasicComponent`（同梱 basic カタログの sum 型）を `ComponentNode` として準拠させる拡張。
///
/// `id` / `componentName` は `BasicComponent` 自体に定義済みのため、ルーティングセットのみ追加する。
/// ルーティングセットは各コンポーネントの `componentName` 定数（スキーマ SSOT）から構築されるため
/// 文字列リテラルは存在しない。`GeneratedSchemaEquivalence` が public カタログの完全性を CI で担保する。
extension BasicComponent: ComponentNode {
    public static let componentNames: Set<String> = [
        TextComponent.componentName,
        ImageComponent.componentName,
        IconComponent.componentName,
        VideoComponent.componentName,
        AudioPlayerComponent.componentName,
        RowComponent.componentName,
        ColumnComponent.componentName,
        ListComponent.componentName,
        CardComponent.componentName,
        TabsComponent.componentName,
        ModalComponent.componentName,
        DividerComponent.componentName,
        ButtonComponent.componentName,
        TextFieldComponent.componentName,
        CheckBoxComponent.componentName,
        ChoicePickerComponent.componentName,
        SliderComponent.componentName,
        DateTimeInputComponent.componentName,
    ]
}

/// swift-a2ui に同梱される basic カタログのコンパイル時 `A2UICatalog` 実装。
///
/// 独自コンポーネントとの合成例: `CombinedNode<MyNode, BasicComponent>`。
public enum BasicCatalog: A2UICatalog {
    public typealias Node = BasicComponent
    public static let catalogId = BasicComponentCatalog.catalogId
}

/// Basic カタログを直接（`BasicComponent`）または合成（`CombinedNode<MyNode, BasicComponent>`）で
/// 埋め込むノード sum 型が準拠するプロトコル。
///
/// 汎用 basic レンダラーが `ComponentNode` が提供しない 2 つのプロジェクションを必要とするため定義する:
/// 子コンポーネント種別の判定（chip 行など）のための embedded basic コンポーネントと、
/// レイアウト weight（flex-grow に相当）。
public protocol BasicEmbeddingNode: ComponentNode {
    /// 内部の `BasicComponent`（non-basic ノードは nil を返す）。
    var basicComponent: BasicComponent? { get }
    /// レイアウトの weight（flex-grow に相当）。
    var layoutWeight: Double? { get }
}

extension BasicComponent: BasicEmbeddingNode {
    public var basicComponent: BasicComponent? { self }
    public var layoutWeight: Double? { weight }
}

extension CombinedNode: BasicEmbeddingNode where Primary: BasicEmbeddingNode, Fallback: BasicEmbeddingNode {
    public var basicComponent: BasicComponent? {
        switch self {
        case .primary(let node): node.basicComponent
        case .fallback(let node): node.basicComponent
        }
    }

    public var layoutWeight: Double? {
        switch self {
        case .primary(let node): node.layoutWeight
        case .fallback(let node): node.layoutWeight
        }
    }
}
