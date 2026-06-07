import A2UICore
import A2UICatalog

/// `BasicComponent` (the bundled basic-catalog sum type) as a `ComponentNode`.
///
/// `id` / `componentName` already exist on `BasicComponent`; only the routing set is added. It is
/// built from each component's `componentName` constant — the schema SSOT — so there are no string
/// literals here, and `GeneratedSchemaEquivalence` (which pins the basic catalog to the official
/// v0.9 `catalog.json`) guards that this set stays complete: a missing basic component fails CI.
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

/// The basic catalog bundled with swift-a2ui, as a compile-time `A2UICatalog`.
///
/// Consumers compose it with their own components: `CombinedNode<MyNode, BasicComponent>`.
public enum BasicCatalog: A2UICatalog {
    public typealias Node = BasicComponent
    public static let catalogId = BasicComponentCatalog.catalogId
}

/// Node sums that embed the basic catalog — directly (`BasicComponent`) or by composition
/// (`CombinedNode<MyNode, BasicComponent>`). The generic basic renderer needs two projections
/// `ComponentNode` doesn't carry: the embedded basic component (for child-kind decisions like
/// chip rows) and the layout weight (flex-grow).
public protocol BasicEmbeddingNode: ComponentNode {
    var basicComponent: BasicComponent? { get }
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
