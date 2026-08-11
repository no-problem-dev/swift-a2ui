# ``A2UICatalog``

The A2UI basic catalog in Swift: the components an agent can build a surface from, the enums that
constrain their properties, and the machinery that turns both into the schema a model is prompted
with.

> **Unofficial.** Not affiliated with or endorsed by the authors of the A2UI protocol. Conforming to the specification is not a goal of this project.

## Overview

`A2UICatalog` implements the 18 components of the A2UI v1.0 basic catalog on top of `A2UICore`'s
`A2UIComponentProtocol`. Display components (``TextComponent``, ``ImageComponent``,
``IconComponent``, ``AudioPlayerComponent``, ``VideoComponent``) only show information. Input
components (``ButtonComponent``, ``TextFieldComponent``, ``CheckBoxComponent``, ``SliderComponent``,
``ChoicePickerComponent``, ``DateTimeInputComponent``) take user interaction and can carry
validation `checks`. Layout components (``RowComponent``, ``ColumnComponent``, ``CardComponent``,
``ListComponent``, ``TabsComponent``, ``ModalComponent``, ``DividerComponent``) give the tree its
structure.

A component never contains another component inline: it names one by ID, and the surface holds the
flat list. So a `Card` that should show several things points at a `Column`, and a data-driven list
is a `List` whose `children` is a template expanded over a path in the data model. Values marked
dynamic — most `String`, number, and boolean properties — accept a literal, a data binding, or a
catalog function call; A2UI has no string concatenation, so interpolation goes through
`formatString`.

``BasicComponent`` is the closed enum a decoded surface arrives as. It dispatches on the wire's
`component` discriminator and throws on a name it does not know, so a surface aimed at another
catalog fails loudly rather than rendering blank.

The schema the model sees is generated from these Swift types rather than from a checked-in
`catalog.json`: each component supplies a ``ComponentSchema`` through ``CatalogSchemaDescribing``,
property enums expose their cases through ``SchemaEnumerable``, and ``SchemaRenderer`` renders the
catalog document that ``BasicCatalogSchema/render()`` returns. One consequence is worth knowing
before editing: every `description` string in those schemas is copied verbatim from the official
catalog and pinned by the fidelity tests, so rewording one breaks the build.

```swift
import A2UICatalog

// A button is labeled by a child component referenced by ID, not by an inline string.
let button = ButtonComponent(
    id: "submit",
    child: "submit-label",
    action: .event(EventAction(name: "onSubmit")),
    variant: .primary
)

// The catalog document to embed in the model's prompt.
let schema = BasicCatalogSchema.render()
```

## Topics

### Catalogs

- ``ComponentCatalog``
- ``BasicComponentCatalog``
- ``BasicComponent``

### Display components

- ``TextComponent``
- ``ImageComponent``
- ``IconComponent``
- ``AudioPlayerComponent``
- ``VideoComponent``

### Layout components

- ``RowComponent``
- ``ColumnComponent``
- ``ListComponent``
- ``CardComponent``
- ``TabsComponent``
- ``TabItem``
- ``ModalComponent``
- ``DividerComponent``

### Input components

- ``ButtonComponent``
- ``TextFieldComponent``
- ``CheckBoxComponent``
- ``ChoicePickerComponent``
- ``ChoiceOption``
- ``SliderComponent``
- ``DateTimeInputComponent``

### Property values

- ``TextVariant``
- ``ButtonVariant``
- ``TextFieldVariant``
- ``ImageVariant``
- ``ImageFit``
- ``IconName``
- ``IconNameValue``
- ``ListDirection``
- ``LayoutJustify``
- ``LayoutAlign``
- ``ChoicePickerVariant``
- ``ChoicePickerDisplayStyle``
- ``DividerAxis``

### Generating the schema

- ``BasicCatalogSchema``
- ``SchemaRenderer``
- ``CatalogSchemaDescribing``
- ``SchemaEnumerable``

### Describing a custom catalog

- ``ComponentSchema``
- ``PropertySchema``
- ``PropertyType``
- ``FunctionSchema``
