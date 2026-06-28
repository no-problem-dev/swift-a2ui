import A2UICore

/// Basic カタログのコンポーネントを網羅する closed enum。
///
/// `component` フィールドの文字列ディスクリミネータに基づいてデコード/エンコードする。
/// 各ケースは対応する `A2UIComponentProtocol` 準拠型を保持する。
public enum BasicComponent: Sendable, Equatable {
    case text(TextComponent)
    case image(ImageComponent)
    case icon(IconComponent)
    case video(VideoComponent)
    case audioPlayer(AudioPlayerComponent)
    case row(RowComponent)
    case column(ColumnComponent)
    case list(ListComponent)
    case card(CardComponent)
    case tabs(TabsComponent)
    case modal(ModalComponent)
    case divider(DividerComponent)
    case button(ButtonComponent)
    case textField(TextFieldComponent)
    case checkBox(CheckBoxComponent)
    case choicePicker(ChoicePickerComponent)
    case slider(SliderComponent)
    case dateTimeInput(DateTimeInputComponent)
}

extension BasicComponent: Codable {
    private enum CodingKeys: String, CodingKey {
        case component
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let componentType = try container.decode(String.self, forKey: .component)

        switch componentType {
        case TextComponent.componentName:
            self = .text(try TextComponent(from: decoder))
        case ImageComponent.componentName:
            self = .image(try ImageComponent(from: decoder))
        case IconComponent.componentName:
            self = .icon(try IconComponent(from: decoder))
        case VideoComponent.componentName:
            self = .video(try VideoComponent(from: decoder))
        case AudioPlayerComponent.componentName:
            self = .audioPlayer(try AudioPlayerComponent(from: decoder))
        case RowComponent.componentName:
            self = .row(try RowComponent(from: decoder))
        case ColumnComponent.componentName:
            self = .column(try ColumnComponent(from: decoder))
        case ListComponent.componentName:
            self = .list(try ListComponent(from: decoder))
        case CardComponent.componentName:
            self = .card(try CardComponent(from: decoder))
        case TabsComponent.componentName:
            self = .tabs(try TabsComponent(from: decoder))
        case ModalComponent.componentName:
            self = .modal(try ModalComponent(from: decoder))
        case DividerComponent.componentName:
            self = .divider(try DividerComponent(from: decoder))
        case ButtonComponent.componentName:
            self = .button(try ButtonComponent(from: decoder))
        case TextFieldComponent.componentName:
            self = .textField(try TextFieldComponent(from: decoder))
        case CheckBoxComponent.componentName:
            self = .checkBox(try CheckBoxComponent(from: decoder))
        case ChoicePickerComponent.componentName:
            self = .choicePicker(try ChoicePickerComponent(from: decoder))
        case SliderComponent.componentName:
            self = .slider(try SliderComponent(from: decoder))
        case DateTimeInputComponent.componentName:
            self = .dateTimeInput(try DateTimeInputComponent(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .component,
                in: container,
                debugDescription: "Unknown component type: \(componentType)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let c): try c.encode(to: encoder)
        case .image(let c): try c.encode(to: encoder)
        case .icon(let c): try c.encode(to: encoder)
        case .video(let c): try c.encode(to: encoder)
        case .audioPlayer(let c): try c.encode(to: encoder)
        case .row(let c): try c.encode(to: encoder)
        case .column(let c): try c.encode(to: encoder)
        case .list(let c): try c.encode(to: encoder)
        case .card(let c): try c.encode(to: encoder)
        case .tabs(let c): try c.encode(to: encoder)
        case .modal(let c): try c.encode(to: encoder)
        case .divider(let c): try c.encode(to: encoder)
        case .button(let c): try c.encode(to: encoder)
        case .textField(let c): try c.encode(to: encoder)
        case .checkBox(let c): try c.encode(to: encoder)
        case .choicePicker(let c): try c.encode(to: encoder)
        case .slider(let c): try c.encode(to: encoder)
        case .dateTimeInput(let c): try c.encode(to: encoder)
        }
    }
}

extension BasicComponent {
    /// コンポーネントインスタンスの id。
    public var id: ComponentId {
        switch self {
        case .text(let c): c.id
        case .image(let c): c.id
        case .icon(let c): c.id
        case .video(let c): c.id
        case .audioPlayer(let c): c.id
        case .row(let c): c.id
        case .column(let c): c.id
        case .list(let c): c.id
        case .card(let c): c.id
        case .tabs(let c): c.id
        case .modal(let c): c.id
        case .divider(let c): c.id
        case .button(let c): c.id
        case .textField(let c): c.id
        case .checkBox(let c): c.id
        case .choicePicker(let c): c.id
        case .slider(let c): c.id
        case .dateTimeInput(let c): c.id
        }
    }

    /// Row / Column 直下での flex-grow 相当(catalog.json CatalogComponentCommon.weight)。
    public var weight: Double? {
        switch self {
        case .text(let c): c.weight
        case .image(let c): c.weight
        case .icon(let c): c.weight
        case .video(let c): c.weight
        case .audioPlayer(let c): c.weight
        case .row(let c): c.weight
        case .column(let c): c.weight
        case .list(let c): c.weight
        case .card(let c): c.weight
        case .tabs(let c): c.weight
        case .modal(let c): c.weight
        case .divider(let c): c.weight
        case .button(let c): c.weight
        case .textField(let c): c.weight
        case .checkBox(let c): c.weight
        case .choicePicker(let c): c.weight
        case .slider(let c): c.weight
        case .dateTimeInput(let c): c.weight
        }
    }

    /// ワイヤー上の `component` ディスクリミネータ文字列。
    public var componentName: String {
        switch self {
        case .text: TextComponent.componentName
        case .image: ImageComponent.componentName
        case .icon: IconComponent.componentName
        case .video: VideoComponent.componentName
        case .audioPlayer: AudioPlayerComponent.componentName
        case .row: RowComponent.componentName
        case .column: ColumnComponent.componentName
        case .list: ListComponent.componentName
        case .card: CardComponent.componentName
        case .tabs: TabsComponent.componentName
        case .modal: ModalComponent.componentName
        case .divider: DividerComponent.componentName
        case .button: ButtonComponent.componentName
        case .textField: TextFieldComponent.componentName
        case .checkBox: CheckBoxComponent.componentName
        case .choicePicker: ChoicePickerComponent.componentName
        case .slider: SliderComponent.componentName
        case .dateTimeInput: DateTimeInputComponent.componentName
        }
    }
}
