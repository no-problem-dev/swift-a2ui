# ``A2UICatalog``

A2UI 標準コンポーネントカタログ — コンポーネント定義・スキーマ記述・バリアント列挙型を提供する。

## Overview

`A2UICatalog` は `A2UICore` の `A2UIComponentProtocol` を実装した具体的なコンポーネント群と、それらのスキーマ記述インフラを定義する。このモジュールをインポートすることで、`ButtonComponent`・`TextComponent`・`TextFieldComponent` などの標準コンポーネントと、`ComponentCatalog` プロトコルを介したカタログ登録機能を利用できる。

コンポーネントは役割別に 3 つに分類される。**表示コンポーネント**（`TextComponent`・`ImageComponent`・`IconComponent`・`AudioPlayerComponent`・`VideoComponent`）は情報を見せるだけの読み取り専用要素。**入力コンポーネント**（`ButtonComponent`・`TextFieldComponent`・`CheckBoxComponent`・`SliderComponent`・`ChoicePickerComponent`・`DateTimeInputComponent`）はユーザーの操作を受け取る。**レイアウトコンポーネント**（`RowComponent`・`ColumnComponent`・`CardComponent`・`ListComponent`・`TabsComponent`・`ModalComponent`・`DividerComponent`）はコンポーネントツリーを構造化する。

`BasicCatalogSchema` はすべての標準コンポーネントの JSON スキーマをプログラム的に生成する。`SchemaRenderer` はそのスキーマをプロンプト埋め込み用のテキストに変換し、`A2UIPrompt` モジュールが利用する。

```swift
import A2UICatalog

// ボタンコンポーネントを定義する（child に子コンポーネント ID、action にイベントを指定）
let button = ButtonComponent(
    id: "submit",
    child: "submit-label",
    action: .event(EventAction(name: "onSubmit")),
    variant: .primary
)

// LLM プロンプト用カタログスキーマを生成する
let schema = BasicCatalogSchema.render()
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
