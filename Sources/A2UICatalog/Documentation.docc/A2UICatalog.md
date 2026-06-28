# ``A2UICatalog``

A2UI 標準コンポーネントカタログ — コンポーネント定義・スキーマ記述・バリアント列挙型を提供する。

## Overview

`A2UICatalog` は `A2UICore` の `A2UIComponentProtocol` を実装した具体的なコンポーネント群と、それらのスキーマ記述インフラを定義します。このモジュールをインポートすることで、`ButtonComponent`・`TextComponent`・`TextFieldComponent` などの標準コンポーネントと、`ComponentCatalog` プロトコルを介したカタログ登録機能を利用できます。

コンポーネントは役割別に 3 つに分類されています。**表示コンポーネント**（`TextComponent`・`ImageComponent`・`IconComponent`・`AudioPlayerComponent`・`VideoPlayerComponent`）は情報を見せるだけの読み取り専用要素です。**入力コンポーネント**（`ButtonComponent`・`TextFieldComponent`・`CheckBoxComponent`・`SliderComponent`・`ChoicePickerComponent`・`DateTimeInputComponent`）はユーザーの操作を受け取ります。**レイアウトコンポーネント**（`RowComponent`・`ColumnComponent`・`CardComponent`・`ListComponent`・`TabsComponent`・`ModalComponent`・`DividerComponent`）はコンポーネントツリーを構造化します。

`BasicCatalogSchema` はすべての標準コンポーネントの JSON スキーマをプログラム的に生成します。`SchemaRenderer` はそのスキーマをプロンプト埋め込み用のテキストに変換し、`A2UIPrompt` モジュールが利用します。

```swift
import A2UICatalog

// ボタンコンポーネントを定義する
let button = ButtonComponent(
    id: "submit",
    label: .literal("送信"),
    variant: .primary,
    onPress: EventAction(action: .callFunction(
        FunctionCall(name: "submit", callableFrom: .button)
    ))
)

// BasicComponentCatalog でコンポーネントを解決する
let catalog = BasicComponentCatalog()
let schema = BasicCatalogSchema.schema(for: catalog)
```

## Topics

### カタログプロトコル

- ``ComponentCatalog``
- ``BasicComponentCatalog``
- ``BasicComponent``

### 表示コンポーネント

- ``TextComponent``
- ``ImageComponent``
- ``IconComponent``
- ``AudioPlayerComponent``
- ``VideoComponent``

### 入力コンポーネント

- ``ButtonComponent``
- ``TextFieldComponent``
- ``CheckBoxComponent``
- ``SliderComponent``
- ``ChoicePickerComponent``
- ``ChoiceOption``
- ``DateTimeInputComponent``

### レイアウトコンポーネント

- ``RowComponent``
- ``ColumnComponent``
- ``CardComponent``
- ``ListComponent``
- ``TabsComponent``
- ``TabItem``
- ``ModalComponent``
- ``DividerComponent``

### スキーマ記述

- ``CatalogSchemaDescribing``
- ``SchemaEnumerable``
- ``BasicCatalogSchema``
- ``ComponentSchema``
- ``PropertySchema``
- ``PropertyType``
- ``FunctionSchema``
- ``ComponentCategory``
- ``SchemaMixin``
- ``SchemaRenderer``

### バリアント・スタイル列挙型

- ``ButtonVariant``
- ``TextVariant``
- ``TextFieldVariant``
- ``ImageVariant``
- ``ImageFit``
- ``IconName``
- ``IconNameValue``
- ``ListDirection``
- ``LayoutAlign``
- ``LayoutJustify``
- ``ChoicePickerVariant``
- ``ChoicePickerDisplayStyle``
- ``DividerAxis``
