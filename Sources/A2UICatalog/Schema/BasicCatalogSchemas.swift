import A2UICore

// Type-safe schema descriptions for the A2UI Basic Catalog components.
//
// These replace the hand-written `catalog.json` component definitions: the Swift enums and
// property declarations are the single source of truth, and `SchemaRenderer` generates the
// LLM-facing schema from them. Enum cases come from the actual Swift enum types (`SchemaEnumerable`),
// so adding/removing a case updates the schema automatically.

extension TextComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, properties: [
            .required("text", .dynamicString, "The text content to display. Simple Markdown is supported."),
            .optional("variant", .enumeration(TextVariant.self), "A hint for the base text style.", default: .string("body")),
        ])
    }
}

extension ImageComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, properties: [
            .required("url", .dynamicString, "The image URL."),
            .optional("description", .dynamicString, "Accessible description / alt text."),
            .optional("fit", .enumeration(ImageFit.self), "How the image fits its box."),
            .optional("variant", .enumeration(ImageVariant.self), "A hint for the image presentation."),
        ])
    }
}

extension IconComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, properties: [
            .required("name", .enumeration(IconName.self), "The system icon to display."),
        ])
    }
}

extension VideoComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, properties: [
            .required("url", .dynamicString, "The video URL."),
        ])
    }
}

extension AudioPlayerComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, properties: [
            .required("url", .dynamicString, "The audio URL."),
            .optional("description", .dynamicString, "Accessible description."),
        ])
    }
}

extension RowComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, properties: [
            .required("children", .childList, "Child components (static list or data-bound template)."),
            .optional("justify", .enumeration(LayoutJustify.self), "Main-axis distribution."),
            .optional("align", .enumeration(LayoutAlign.self), "Cross-axis alignment."),
        ])
    }
}

extension ColumnComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, properties: [
            .required("children", .childList, "Child components (static list or data-bound template)."),
            .optional("justify", .enumeration(LayoutJustify.self), "Main-axis distribution."),
            .optional("align", .enumeration(LayoutAlign.self), "Cross-axis alignment."),
        ])
    }
}

extension ListComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, properties: [
            .required("children", .childList, "List items (static list or data-bound template)."),
            .optional("direction", .enumeration(ListDirection.self), "Scroll direction."),
            .optional("align", .enumeration(LayoutAlign.self), "Cross-axis alignment."),
        ])
    }
}

extension CardComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, properties: [
            .required("child", .componentId, "The single child component id. Do NOT define it inline."),
        ])
    }
}

extension TabsComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, properties: [
            .required("tabs", .array(.object([
                .required("title", .dynamicString, "Tab title."),
                .required("child", .componentId, "The tab's child component id."),
            ])), "The set of tabs."),
        ])
    }
}

extension DividerComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, properties: [
            .optional("axis", .enumeration(DividerAxis.self), "Divider orientation."),
        ])
    }
}

extension ModalComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, properties: [
            .required("trigger", .componentId, "The component that opens the modal."),
            .required("content", .componentId, "The modal body component."),
        ])
    }
}

extension ButtonComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, properties: [
            .required("child", .componentId, "The button's child component id (usually a Text). Do NOT define it inline."),
            .optional("variant", .enumeration(ButtonVariant.self), "Button style hint.", default: .string("default")),
            .required("action", .action, "What happens on tap (event to the server or local function)."),
        ], mixins: [.checkable])
    }
}

extension TextFieldComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, properties: [
            .required("label", .dynamicString, "Field label."),
            .optional("value", .dynamicString, "Two-way bound value path."),
            .optional("variant", .enumeration(TextFieldVariant.self), "Input style hint."),
            .optional("validationRegexp", .string, "A regex the input must match."),
        ], mixins: [.checkable])
    }
}

extension CheckBoxComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, properties: [
            .required("label", .dynamicString, "Checkbox label."),
            .required("value", .dynamicBoolean, "Two-way bound boolean value path."),
        ], mixins: [.checkable])
    }
}

extension ChoicePickerComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, properties: [
            .optional("label", .dynamicString, "Picker label."),
            .optional("variant", .enumeration(ChoicePickerVariant.self), "Single or multiple selection."),
            .required("options", .array(.object([
                .required("label", .dynamicString, "Option label."),
                .required("value", .string, "Option value."),
            ])), "The selectable options."),
            .required("value", .dynamicStringList, "Two-way bound selection (array of values)."),
            .optional("displayStyle", .enumeration(ChoicePickerDisplayStyle.self), "Visual style."),
            .optional("filterable", .boolean, "Whether options can be filtered."),
        ], mixins: [.checkable])
    }
}

extension SliderComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, properties: [
            .optional("label", .dynamicString, "Slider label."),
            .optional("min", .number, "Minimum value."),
            .required("max", .number, "Maximum value."),
            .required("value", .dynamicNumber, "Two-way bound numeric value path."),
        ], mixins: [.checkable])
    }
}

extension DateTimeInputComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, properties: [
            .required("value", .dynamicString, "Two-way bound ISO 8601 value path."),
            .optional("label", .dynamicString, "Input label."),
            .optional("enableDate", .boolean, "Allow date selection."),
            .optional("enableTime", .boolean, "Allow time selection."),
            .optional("min", .dynamicString, "Minimum selectable value."),
            .optional("max", .dynamicString, "Maximum selectable value."),
        ], mixins: [.checkable])
    }
}
