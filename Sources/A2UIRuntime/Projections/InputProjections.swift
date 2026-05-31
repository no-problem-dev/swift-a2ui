import A2UICatalog
import A2UICore

/// A two-way bound field on an input projection.
///
/// Holds the current **resolved** value and a `set` closure that writes back through the bound
/// path with correct scope resolution (`ResolvedComponent.write`). Wraps the SwiftUI-agnostic
/// runtime API; the consumer's SwiftUI layer wraps `Writable` in a `Binding`.
public struct Writable<Value: Sendable>: Sendable {
    public let value: Value
    public let set: @MainActor (Value) -> Void

    public init(value: Value, set: @escaping @MainActor (Value) -> Void) {
        self.value = value
        self.set = set
    }
}

// MARK: - Button

public struct ResolvedButton: ResolvedProjection {
    public let child: ResolvedChild?
    public let variant: ButtonVariant
    public let isEnabled: Bool
    public let validationMessage: String?
    /// Performs the button's `action` (event dispatch or local function call).
    public let perform: @MainActor () -> Void

    public init(_ r: ResolvedComponent) {
        child = r.children.first
        variant = r.decode(ButtonVariant.self, "variant") ?? .default
        isEnabled = r.validationMessage == nil
        validationMessage = r.validationMessage
        // Action performance lives on the projection so views never touch the raw `action` prop.
        perform = { [weak r] in r?.performAction() }
    }
}

// MARK: - TextField

public struct ResolvedTextField: ResolvedProjection {
    public let label: String
    public let value: Writable<String>
    public let variant: TextFieldVariant?
    public let validationRegexp: String?
    public let validationMessage: String?

    public init(_ r: ResolvedComponent) {
        label = r.text("label")
        value = Writable(value: r.string("value") ?? "", set: { [weak r] new in r?.write("value", .string(new)) })
        variant = r.decode(TextFieldVariant.self, "variant")
        if case .string(let raw)? = r.rawProps["validationRegexp"] {
            validationRegexp = raw
        } else {
            validationRegexp = nil
        }
        validationMessage = r.validationMessage
    }
}

// MARK: - CheckBox

public struct ResolvedCheckBox: ResolvedProjection {
    public let label: String
    public let value: Writable<Bool>
    public let validationMessage: String?
    public init(_ r: ResolvedComponent) {
        label = r.text("label")
        value = Writable(value: r.bool("value"), set: { [weak r] new in r?.write("value", .bool(new)) })
        validationMessage = r.validationMessage
    }
}

// MARK: - Slider

public struct ResolvedSlider: ResolvedProjection {
    public let label: String?
    public let min: Double
    public let max: Double
    public let value: Writable<Double>
    public let validationMessage: String?

    public init(_ r: ResolvedComponent) {
        label = r.string("label")
        let minV = r.double("min") ?? 0
        min = minV
        max = r.double("max") ?? 1
        value = Writable(value: r.double("value") ?? minV, set: { [weak r] new in r?.write("value", .double(new)) })
        validationMessage = r.validationMessage
    }
}

// MARK: - ChoicePicker

/// One option in a `ChoicePicker` — decoded from the static `options` array on the raw props.
public struct ResolvedChoiceOption: Sendable, Equatable {
    public let label: String
    public let value: String
}

public struct ResolvedChoicePicker: ResolvedProjection {
    public let label: String?
    public let options: [ResolvedChoiceOption]
    public let selection: Writable<[String]>
    public let variant: ChoicePickerVariant?
    public let displayStyle: ChoicePickerDisplayStyle?
    public let filterable: Bool
    public let validationMessage: String?

    public init(_ r: ResolvedComponent) {
        label = r.string("label")
        var opts: [ResolvedChoiceOption] = []
        if case .array(let arr)? = r.rawProps["options"] {
            for item in arr {
                if case .object(let dict) = item,
                   case .string(let v)? = dict["value"] {
                    // Option `label` is a `DynamicString` — resolve bindings/functions through
                    // the runtime so dynamic labels work. Falls back to the value when missing.
                    let resolved = r.resolveDynamicString(dict["label"])
                    let lbl = resolved.isEmpty ? v : resolved
                    opts.append(ResolvedChoiceOption(label: lbl, value: v))
                }
            }
        }
        options = opts
        selection = Writable(value: r.stringArray("value"), set: { [weak r] new in
            r?.write("value", .array(new.map(StructuredValue.string)))
        })
        variant = r.decode(ChoicePickerVariant.self, "variant")
        displayStyle = r.decode(ChoicePickerDisplayStyle.self, "displayStyle")
        if case .bool(let b)? = r.rawProps["filterable"] { filterable = b } else { filterable = false }
        validationMessage = r.validationMessage
    }
}

// MARK: - DateTimeInput

public struct ResolvedDateTimeInput: ResolvedProjection {
    public let label: String?
    public let value: Writable<String>   // ISO 8601 string; views convert to/from Date
    public let enableDate: Bool
    public let enableTime: Bool
    public let min: String?
    public let max: String?
    public let validationMessage: String?

    public init(_ r: ResolvedComponent) {
        label = r.string("label")
        value = Writable(value: r.string("value") ?? "", set: { [weak r] new in r?.write("value", .string(new)) })
        enableDate = r.bool("enableDate") || (r.props["enableDate"] == nil && r.props["enableTime"] == nil)
        enableTime = r.bool("enableTime")
        min = r.string("min")
        max = r.string("max")
        validationMessage = r.validationMessage
    }
}
