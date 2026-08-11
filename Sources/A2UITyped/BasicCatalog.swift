import A2UICore
import A2UICatalog

/// Conforms `BasicComponent`, the sum type of the bundled basic catalog, to `ComponentNode`.
///
/// `id` and `componentName` already live on `BasicComponent`, so only the routing set is added here. It
/// is built from each component's `componentName` constant (the schema's source of truth), which is why
/// no string literal appears below; `GeneratedSchemaEquivalence` keeps the set complete in CI.
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

/// The compile-time `A2UICatalog` for the basic catalog bundled with swift-a2ui.
///
/// Use it as-is to render only standard components; to add your own, compose the node types instead:
/// `CombinedNode<MyNode, BasicComponent>`.
public enum BasicCatalog: A2UICatalog {
    public typealias Node = BasicComponent
    public static let catalogId = BasicComponentCatalog.catalogId
    /// Every basic-catalog function omits `callableFrom`, so all of them are `rendererOnly` and no
    /// agent may invoke one remotely.
    public static let functions = BasicCatalogSchema.functions
}

/// A node sum type that embeds the basic catalog, either directly or through composition.
///
/// Conformers are `BasicComponent` itself and `CombinedNode<MyNode, BasicComponent>`. The general-purpose
/// basic renderer needs two projections `ComponentNode` does not offer: the embedded basic component, so
/// it can tell what kind a child is (a row of chips, say), and the layout weight.
public protocol BasicEmbeddingNode: ComponentNode {
    /// The `BasicComponent` inside, or `nil` for a consumer-defined node that wraps none.
    var basicComponent: BasicComponent? { get }
    /// The layout weight, the equivalent of `flex-grow`; `nil` when the component declares none, which
    /// is what lets a row of same-kind children fall back to chip scrolling instead of flex layout.
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
