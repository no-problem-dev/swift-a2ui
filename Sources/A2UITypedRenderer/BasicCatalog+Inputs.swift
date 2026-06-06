import SwiftUI
import DesignSystem
import A2UICore
import A2UICatalog
import A2UITyped

// Interactive components — faithful ports of A2UIRenderer.InputViews, fed by typed props and the
// two-way `RenderContext.binding(_:)` helpers instead of `ResolvedComponent`/`Writable`.

/// `Button` — variant styles + action dispatch (faithful port of ButtonView).
struct ButtonNodeView: View {
    @Environment(\.colorPalette) private var colors
    @Environment(\.spacingScale) private var spacing
    let component: ButtonComponent
    let ctx: RenderContext<BasicCatalog>

    var body: some View {
        // Spec: a Button whose `checks` fail is automatically disabled.
        content.disabled(!ctx.checksPass(component.checks))
    }

    @ViewBuilder private var content: some View {
        switch component.variant {
        case .primary:
            Button { ctx.dispatch(component.action, from: component.id) } label: {
                ctx.child(component.child).frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        case .borderless:
            Button { ctx.dispatch(component.action, from: component.id) } label: {
                ctx.child(component.child)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, spacing.md)
                    .padding(.vertical, spacing.sm)
                    .background(colors.surfaceVariant, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        case .default, .none:
            Button { ctx.dispatch(component.action, from: component.id) } label: {
                ctx.child(component.child)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }
}

/// `TextField` — faithful port of TextFieldView.
struct TextFieldNodeView: View {
    let component: TextFieldComponent
    let ctx: RenderContext<BasicCatalog>

    var body: some View {
        let label = ctx.resolve(component.label)
        let placeholder = component.placeholder.map { ctx.resolve($0) } ?? label
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

/// `CheckBox` — faithful port of CheckBoxView.
struct CheckBoxNodeView: View {
    @Environment(\.colorPalette) private var colors
    let component: CheckBoxComponent
    let ctx: RenderContext<BasicCatalog>

    var body: some View {
        Toggle(isOn: ctx.binding(component.value)) {
            Text(ctx.resolve(component.label)).typography(.bodyMedium).foregroundStyle(colors.onSurface)
        }
        .tint(colors.primary)
    }
}

/// `Slider` — faithful port of SliderView.
struct SliderNodeView: View {
    @Environment(\.colorPalette) private var colors
    @Environment(\.spacingScale) private var spacing
    let component: SliderComponent
    let ctx: RenderContext<BasicCatalog>

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

/// `ChoicePicker` — faithful port of ChoicePickerView + FlowChips.
struct ChoicePickerNodeView: View {
    @Environment(\.colorPalette) private var colors
    @Environment(\.spacingScale) private var spacing
    let component: ChoicePickerComponent
    let ctx: RenderContext<BasicCatalog>

    private var multiple: Bool { component.variant == .multipleSelection }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.xs) {
            if let label = component.label {
                Text(ctx.resolve(label)).typography(.labelMedium).foregroundStyle(colors.onSurfaceVariant)
            }
            FlowChips(
                options: component.options.map { (label: ctx.resolve($0.label), value: $0.value) },
                selection: ctx.resolveStringList(component.value)
            ) { toggle($0) }
        }
    }

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

/// `DateTimeInput` — faithful port of DateTimeInputView.
struct DateTimeInputNodeView: View {
    @Environment(\.colorPalette) private var colors
    @Environment(\.spacingScale) private var spacing
    let component: DateTimeInputComponent
    let ctx: RenderContext<BasicCatalog>

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

/// Selectable chip group for ChoicePicker (faithful port of the private FlowChips).
private struct FlowChips: View {
    @Environment(\.colorPalette) private var colors
    let options: [(label: String, value: String)]
    let selection: [String]
    let onToggle: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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
