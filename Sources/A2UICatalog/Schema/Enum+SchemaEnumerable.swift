// Conform the catalog's property enums to `SchemaEnumerable` so their cases feed the generated
// schema directly from Swift (no hand-listed enum strings in any JSON).
//
// `CaseIterable` is synthesized for these no-payload enums; declaring it in an extension within
// the same module is sufficient and avoids touching each enum's declaration.

// (CaseIterable is declared on each enum in its own file — required for allCases synthesis.)
extension TextVariant: SchemaEnumerable {}
extension ButtonVariant: SchemaEnumerable {}
extension ImageFit: SchemaEnumerable {}
extension ImageVariant: SchemaEnumerable {}
extension LayoutAlign: SchemaEnumerable {}
extension LayoutJustify: SchemaEnumerable {}
extension ListDirection: SchemaEnumerable {}
extension DividerAxis: SchemaEnumerable {}
extension TextFieldVariant: SchemaEnumerable {}
extension ChoicePickerVariant: SchemaEnumerable {}
extension ChoicePickerDisplayStyle: SchemaEnumerable {}
extension IconName: SchemaEnumerable {}
