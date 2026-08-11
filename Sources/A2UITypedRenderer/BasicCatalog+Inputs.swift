import SwiftUI
import DesignSystem
import A2UICore
import A2UICatalog
import A2UITyped

// Interactive components — faithful ports of A2UIRenderer.InputViews, fed by typed props and the
// two-way `RenderContext.binding(_:)` helpers instead of `ResolvedComponent`/`Writable`.

/// `Button` — maps the `variant` to a button style and dispatches the component's action.
///
/// Follows the host's `surfaceStyle` environment: under a glass style it renders as a Liquid Glass
/// button instead of a solid fill — tinted for `primary`, neutral glass for `default`, a glass chip
/// for `borderless` — so buttons and cards speak the same design language.
struct ButtonNodeView<Catalog: RenderableCatalog>: View where Catalog.Node: BasicEmbeddingNode {
    @Environment(\.colorPalette) private var colors
    @Environment(\.spacingScale) private var spacing
    @Environment(\.surfaceStyle) private var surfaceStyle
    let component: ButtonComponent
    let ctx: RenderContext<Catalog>

    private var isGlass: Bool { surfaceStyle != .solid }

    var body: some View {
        // Spec: a Button whose `checks` fail is automatically disabled.
        content.disabled(!ctx.checksPass(component.checks))
    }

    // Buttons are drawn only through the design system's styles (glass / solid). The macOS sizing
    // and content width are handled platform-aware inside DesignSystem (ButtonSize and the button
    // styles), so the renderer carries no platform branch of its own.
    @ViewBuilder private var content: some View {
        switch component.variant {
        case .primary:
            let button = Button(action: action) { ctx.child(component.child) }
            if isGlass { button.buttonStyle(.primaryGlass) } else { button.buttonStyle(PrimaryButtonStyle()) }
        case .borderless:
            Button(action: action) {
                ctx.child(component.child)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, spacing.md)
                    .padding(.vertical, spacing.sm)
                    .background { chipBackground }
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        case .default, .none:
            let button = Button(action: action) { ctx.child(component.child) }
            if isGlass { button.buttonStyle(.glass) } else { button.buttonStyle(SecondaryButtonStyle()) }
        }
    }

    private func action() { ctx.dispatch(component.action, from: component.id) }

    /// Background for the borderless chip: a frosted-material capsule under a glass style.
    ///
    /// Material rather than `glassEffect`, because chips usually sit in a horizontally scrolling
    /// row and `glassEffect` there paints one glass slab across the full width of the scroll
    /// content instead of per chip.
    @ViewBuilder private var chipBackground: some View {
        if isGlass {
            Capsule().fill(.ultraThinMaterial)
                .overlay {
                    Capsule().strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                }
        } else {
            Capsule().fill(colors.surfaceVariant)
        }
    }
}

/// `TextField` — the `longText` variant grows vertically, `number` brings up the decimal pad on
/// iOS, and a failing `check` surfaces as the field's error message rather than disabling it.
struct TextFieldNodeView<Catalog: RenderableCatalog>: View where Catalog.Node: BasicEmbeddingNode {
    let component: TextFieldComponent
    let ctx: RenderContext<Catalog>

    var body: some View {
        let label = ctx.resolve(component.label)
        let placeholder = component.placeholder.map { ctx.resolve($0) } ?? label
        // Always DSTextField; DesignSystem shrinks the field height on macOS platform-aware.
        let field = DSTextField(
            label,
            text: ctx.binding(component.value),
            placeholder: placeholder,
            axis: component.variant == .longText ? .vertical : .horizontal,
            error: ctx.firstCheckFailure(component.checks)
        )
        #if os(iOS)
        field.keyboardType(component.variant == .number ? .decimalPad : .default)
        #else
        field
        #endif
    }
}

/// `CheckBox` — a `Toggle` writing straight back to the bound boolean path.
struct CheckBoxNodeView<Catalog: RenderableCatalog>: View where Catalog.Node: BasicEmbeddingNode {
    @Environment(\.colorPalette) private var colors
    let component: CheckBoxComponent
    let ctx: RenderContext<Catalog>

    var body: some View {
        Toggle(isOn: ctx.binding(component.value)) {
            Text(ctx.resolve(component.label)).typography(.bodyMedium).foregroundStyle(colors.onSurface)
        }
        .tint(colors.primary)
    }
}

/// `Slider` — `steps` turns the continuous range into that many increments. The upper bound is
/// nudged above the lower one so a degenerate `min == max` range cannot trap `Slider`.
struct SliderNodeView<Catalog: RenderableCatalog>: View where Catalog.Node: BasicEmbeddingNode {
    @Environment(\.colorPalette) private var colors
    @Environment(\.spacingScale) private var spacing
    let component: SliderComponent
    let ctx: RenderContext<Catalog>

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.xs) {
            if let label = component.label {
                Text(ctx.resolve(label)).typography(.labelMedium).foregroundStyle(colors.onSurfaceVariant)
            }
            let lo = component.min ?? 0
            let hi = Swift.max(component.max, lo + 0.0001)
            if let steps = component.steps, steps >= 1 {
                Slider(value: ctx.binding(component.value), in: lo...hi, step: (hi - lo) / Double(steps))
                    .tint(colors.primary)
            } else {
                Slider(value: ctx.binding(component.value), in: lo...hi)
                    .tint(colors.primary)
            }
        }
    }
}

/// `ChoicePicker` — chips on iOS, native selection controls on macOS. The bound value is always a
/// string array, and a single-selection picker writes a one-element array rather than a scalar.
struct ChoicePickerNodeView<Catalog: RenderableCatalog>: View where Catalog.Node: BasicEmbeddingNode {
    @Environment(\.colorPalette) private var colors
    @Environment(\.spacingScale) private var spacing
    let component: ChoicePickerComponent
    let ctx: RenderContext<Catalog>

    private var multiple: Bool { component.variant == .multipleSelection }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.xs) {
            if let label = component.label {
                Text(ctx.resolve(label)).typography(.labelMedium).foregroundStyle(colors.onSurfaceVariant)
            }
            #if os(macOS)
            // The stock macOS selection controls: checkboxes for multiple selection, a radio group
            // for a few single-selection options, and a pop-up menu once there are many. No chips.
            macSelection
            #else
            FlowChips(
                options: component.options.map { (label: ctx.resolve($0.label), value: $0.value) },
                selection: ctx.resolveStringList(component.value)
            ) { toggle($0) }
            #endif
        }
    }

    #if os(macOS)
    @ViewBuilder private var macSelection: some View {
        let options = component.options.map { (label: ctx.resolve($0.label), value: $0.value) }
        if multiple {
            VStack(alignment: .leading, spacing: spacing.xs) {
                ForEach(options, id: \.value) { option in
                    Toggle(option.label, isOn: checkboxBinding(option.value))
                        .toggleStyle(.checkbox)
                }
            }
        } else {
            let picker = Picker(selection: singleBinding) {
                ForEach(options, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            } label: { EmptyView() }
                .labelsHidden()
            if options.count <= 6 {
                picker.pickerStyle(.radioGroup)
            } else {
                picker.pickerStyle(.menu)
            }
        }
    }

    private var singleBinding: Binding<String> {
        Binding(
            get: { ctx.resolveStringList(component.value).first ?? "" },
            set: { ctx.writeStringList(component.value, [$0]) }
        )
    }

    private func checkboxBinding(_ value: String) -> Binding<Bool> {
        Binding(
            get: { ctx.resolveStringList(component.value).contains(value) },
            set: { isOn in
                var current = ctx.resolveStringList(component.value)
                if isOn {
                    if !current.contains(value) { current.append(value) }
                } else {
                    current.removeAll { $0 == value }
                }
                ctx.writeStringList(component.value, current)
            }
        )
    }
    #endif

    private func toggle(_ value: String) {
        var current = ctx.resolveStringList(component.value)
        if multiple {
            if let index = current.firstIndex(of: value) { current.remove(at: index) } else { current.append(value) }
        } else {
            current = [value]
        }
        ctx.writeStringList(component.value, current)
    }
}

/// `DateTimeInput` — `enableDate` / `enableTime` pick which `DatePicker` fields show; date only is
/// the default. The bound value is an ISO 8601 string, and anything unparseable reads as now.
struct DateTimeInputNodeView<Catalog: RenderableCatalog>: View where Catalog.Node: BasicEmbeddingNode {
    @Environment(\.colorPalette) private var colors
    @Environment(\.spacingScale) private var spacing
    let component: DateTimeInputComponent
    let ctx: RenderContext<Catalog>

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.xs) {
            if let label = component.label {
                Text(ctx.resolve(label)).typography(.labelMedium).foregroundStyle(colors.onSurfaceVariant)
            }
            DatePicker("", selection: dateBinding, displayedComponents: components)
                .labelsHidden()
        }
    }

    private var components: DatePickerComponents {
        let enableDate = component.enableDate ?? true
        let enableTime = component.enableTime ?? false
        if enableDate && enableTime { return [.date, .hourAndMinute] }
        return enableTime ? [.hourAndMinute] : [.date]
    }

    private var dateBinding: Binding<Date> {
        let string = ctx.binding(component.value)
        return Binding(
            get: { ISO8601DateFormatter().date(from: string.wrappedValue) ?? Date() },
            set: { string.wrappedValue = ISO8601DateFormatter().string(from: $0) }
        )
    }
}

/// The selectable chip group behind `ChoicePicker` on iOS. Selection is passed in and reported back
/// through `onToggle`, so the chips hold no state of their own.
private struct FlowChips: View {
    @Environment(\.colorPalette) private var colors
    @Environment(\.spacingScale) private var spacing
    let options: [(label: String, value: String)]
    let selection: [String]
    let onToggle: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.xs) {
            ForEach(options, id: \.value) { option in
                let selected = selection.contains(option.value)
                Chip(option.label, systemImage: selected ? "checkmark.circle.fill" : "circle")
                    .chipStyle(.outlined).chipSize(.small)
                    .foregroundColor(selected ? colors.primary : colors.onSurfaceVariant)
                    .onTapGesture { onToggle(option.value) }
            }
        }
    }
}
