import A2UICore

// Type-safe schema descriptions for the A2UI Basic Catalog components.
//
// The Swift declarations below are the single source of truth for the LLM-facing schema, and every
// `description` / `default` / structural detail is reproduced **verbatim from the official
// `catalog.json`** so the generated schema is byte-identical to Google's. The
// `GeneratedCatalogFidelityTests` pins this exactness; do not paraphrase.

/// The common-types `$ref` URL string (v0.10) for a `$defs` name.
private func ctURL(_ name: String) -> StructuredValue {
    .string("https://a2ui.org/specification/v0_10/common_types.json#/$defs/\(name)")
}

/// A common-types `$ref` object fragment (v0.10), used inside `.raw` schema fragments.
private func ct(_ name: String) -> StructuredValue {
    .object(["$ref": ctURL(name)])
}

extension TextComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, category: .display, properties: [
            .required("text", .dynamicString, "The text content to display. While simple Markdown formatting is supported (i.e. without HTML, images, or links), utilizing dedicated UI components is generally preferred for a richer and more structured presentation."),
            .optional("variant", .enumeration(TextVariant.self), "A hint for the base text style.", default: .string("body")),
        ])
    }
}

extension ImageComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, category: .display, properties: [
            .required("url", .dynamicString, "The URL of the image to display."),
            .optional("description", .dynamicString, "Accessibility text for the image."),
            .optional("fit", .enumeration(ImageFit.self), "Specifies how the image should be resized to fit its container. This corresponds to the CSS 'object-fit' property.", default: .string("fill")),
            .optional("variant", .enumeration(ImageVariant.self), "A hint for the image size and style.", default: .string("mediumFeature")),
        ])
    }
}

extension IconComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, category: .display, properties: [
            .required("name", .raw(.object([
                "description": .string("The name of the icon to display."),
                "oneOf": .array([
                    .object([
                        "type": .string("string"),
                        "enum": .array(IconName.schemaCases.map { .string($0) }),
                    ]),
                    .object([
                        "type": .string("object"),
                        "properties": .object(["path": .object(["type": .string("string")])]),
                        "required": .array([.string("path")]),
                        "additionalProperties": .bool(false),
                    ]),
                ]),
            ]))),
        ])
    }
}

extension VideoComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, category: .display, properties: [
            .required("url", .dynamicString, "The URL of the video to display."),
            .optional("posterUrl", .dynamicString, "The URL of the poster image to display before the video plays."),
        ])
    }
}

extension AudioPlayerComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, category: .display, properties: [
            .required("url", .dynamicString, "The URL of the audio to be played."),
            .optional("description", .dynamicString, "A description of the audio, such as a title or summary."),
        ])
    }
}

extension RowComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(
            name: componentName,
            category: .layout,
            description: "A layout component that arranges its children horizontally. To create a grid layout, nest Columns within this Row.",
            properties: [
                .required("children", .childList, "Defines the children. Use an array of strings for a fixed set of children, or a template object to generate children from a data list. Children cannot be defined inline, they must be referred to by ID."),
                // Official orders Row.justify alphabetically (Column.justify is logical) — pin it explicitly.
                .optional("justify", .enumeration([LayoutJustify.center, .end, .spaceAround, .spaceBetween, .spaceEvenly, .start, .stretch].map(\.rawValue)), "Defines the arrangement of children along the main axis (horizontally). Use 'spaceBetween' to push items to the edges, or 'start'/'end'/'center' to pack them together.", default: .string("start")),
                .optional("align", .enumeration(LayoutAlign.self), "Defines the alignment of children along the cross axis (vertically). This is similar to the CSS 'align-items' property, but uses camelCase values (e.g., 'start').", default: .string("stretch")),
            ]
        )
    }
}

extension ColumnComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(
            name: componentName,
            category: .layout,
            description: "A layout component that arranges its children vertically. To create a grid layout, nest Rows within this Column.",
            properties: [
                .required("children", .childList, "Defines the children. Use an array of strings for a fixed set of children, or a template object to generate children from a data list. Children cannot be defined inline, they must be referred to by ID."),
                .optional("justify", .enumeration(LayoutJustify.self), "Defines the arrangement of children along the main axis (vertically). Use 'spaceBetween' to push items to the edges (e.g. header at top, footer at bottom), or 'start'/'end'/'center' to pack them together.", default: .string("start")),
                // Official orders Column.align as center,end,start,stretch (differs from Row.align) — pin it explicitly.
                .optional("align", .enumeration([LayoutAlign.center, .end, .start, .stretch].map(\.rawValue)), "Defines the alignment of children along the cross axis (horizontally). This is similar to the CSS 'align-items' property.", default: .string("stretch")),
            ]
        )
    }
}

extension ListComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, category: .layout, properties: [
            .required("children", .childList, "Defines the children. Use an array of strings for a fixed set of children, or a template object to generate children from a data list."),
            .optional("direction", .enumeration(ListDirection.self), "The direction in which the list items are laid out.", default: .string("vertical")),
            .optional("align", .enumeration(LayoutAlign.self), "Defines the alignment of children along the cross axis.", default: .string("stretch")),
        ])
    }
}

extension CardComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, category: .layout, properties: [
            .required("child", .componentId, "The ID of the single child component to be rendered inside the card. To display multiple elements, you MUST wrap them in a layout component (like Column or Row) and pass that container's ID here. Do NOT pass multiple IDs or a non-existent ID. Do NOT define the child component inline."),
        ])
    }
}

extension TabsComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, category: .layout, properties: [
            .required("tabs", .raw(.object([
                "type": .string("array"),
                "description": .string("An array of objects, where each object defines a tab with a title and a child component."),
                "minItems": .int(1),
                "items": .object([
                    "type": .string("object"),
                    "properties": .object([
                        "title": .object(["description": .string("The tab title."), "$ref": ctURL("DynamicString")]),
                        "child": .object(["$ref": ctURL("ComponentId"), "description": .string("The ID of the child component. Do NOT define the component inline.")]),
                    ]),
                    "required": .array([.string("title"), .string("child")]),
                    "additionalProperties": .bool(false),
                ]),
            ]))),
        ])
    }
}

extension DividerComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, category: .layout, properties: [
            .optional("axis", .enumeration(DividerAxis.self), "The orientation of the divider.", default: .string("horizontal")),
        ])
    }
}

extension ModalComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, category: .layout, properties: [
            .required("trigger", .componentId, "The ID of the component that opens the modal when interacted with (e.g., a button). Do NOT define the component inline."),
            .required("content", .componentId, "The ID of the component to be displayed inside the modal. Do NOT define the component inline."),
        ])
    }
}

extension ButtonComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, category: .input, properties: [
            .required("child", .componentId, "The ID of the child component. Use a 'Text' component for a labeled button. Only use an 'Icon' if the requirements explicitly ask for an icon-only button. Do NOT define the child component inline."),
            .optional("variant", .enumeration(ButtonVariant.self), "A hint for the button style. If omitted, a default button style is used. 'primary' indicates this is the main call-to-action button. 'borderless' means the button has no visual border or background, making its child content appear like a clickable link.", default: .string("default")),
            .required("action", .action),
        ], mixins: [.checkable])
    }
}

extension TextFieldComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, category: .input, properties: [
            .required("label", .dynamicString, "The text label for the input field."),
            .optional("value", .dynamicString, "The value of the text field."),
            .optional("variant", .enumeration(TextFieldVariant.self), "The type of input field to display.", default: .string("shortText")),
            .optional("placeholder", .dynamicString, "The placeholder text for the input field."),
        ], mixins: [.checkable])
    }
}

extension CheckBoxComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, category: .input, properties: [
            .required("label", .dynamicString, "The text to display next to the checkbox."),
            .required("value", .dynamicBoolean, "The current state of the checkbox (true for checked, false for unchecked)."),
        ], mixins: [.checkable])
    }
}

extension ChoicePickerComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(
            name: componentName,
            category: .input,
            description: "A component that allows selecting one or more options from a list.",
            properties: [
                .optional("label", .dynamicString, "The label for the group of options."),
                .optional("variant", .enumeration(ChoicePickerVariant.self), "A hint for how the choice picker should be displayed and behave.", default: .string("mutuallyExclusive")),
                .required("options", .raw(.object([
                    "type": .string("array"),
                    "description": .string("The list of available options to choose from."),
                    "items": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "label": .object(["description": .string("The text to display for this option."), "$ref": ctURL("DynamicString")]),
                            "value": .object(["type": .string("string"), "description": .string("The stable value associated with this option.")]),
                        ]),
                        "required": .array([.string("label"), .string("value")]),
                        "additionalProperties": .bool(false),
                    ]),
                ]))),
                .required("value", .dynamicStringList, "The list of currently selected values. This should be bound to a string array in the data model."),
                .optional("displayStyle", .enumeration(ChoicePickerDisplayStyle.self), "The display style of the component.", default: .string("checkbox")),
                .optional("filterable", .boolean, "If true, displays a search input to filter the options.", default: .bool(false)),
            ],
            mixins: [.checkable]
        )
    }
}

extension SliderComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, category: .input, properties: [
            // `value` before `max` so the generated `required` array is ["component","value","max"] (official order).
            .optional("label", .dynamicString, "The label for the slider."),
            .optional("min", .number, "The minimum value of the slider.", default: .int(0)),
            .required("value", .dynamicNumber, "The current value of the slider."),
            .required("max", .number, "The maximum value of the slider."),
            .optional("steps", .raw(.object([
                "type": .string("integer"),
                "minimum": .int(1),
                "description": .string("The number of discrete divisions in the slider range. If specified, the slider will snap to discrete values."),
            ]))),
        ], mixins: [.checkable])
    }
}

extension DateTimeInputComponent: CatalogSchemaDescribing {
    public static var componentSchema: ComponentSchema {
        ComponentSchema(name: componentName, category: .input, properties: [
            .required("value", .dynamicString, "The selected date and/or time value in ISO 8601 format. If not yet set, initialize with an empty string."),
            .optional("enableDate", .boolean, "If true, allows the user to select a date.", default: .bool(false)),
            .optional("enableTime", .boolean, "If true, allows the user to select a time.", default: .bool(false)),
            .optional("min", .raw(dateTimeBound("The minimum allowed date/time in ISO 8601 format."))),
            .optional("max", .raw(dateTimeBound("The maximum allowed date/time in ISO 8601 format."))),
            .optional("label", .dynamicString, "The text label for the input field."),
        ], mixins: [.checkable])
    }
}

/// The official `allOf` shape for DateTimeInput `min`/`max` (DynamicString + an `if/then` format check).
private func dateTimeBound(_ description: String) -> StructuredValue {
    .object([
        "description": .string(description),
        "allOf": .array([
            ct("DynamicString"),
            .object([
                "if": .object(["type": .string("string")]),
                "then": .object([
                    "oneOf": .array([
                        .object(["format": .string("date")]),
                        .object(["format": .string("time")]),
                        .object(["format": .string("date-time")]),
                    ]),
                ]),
            ]),
        ]),
    ])
}
