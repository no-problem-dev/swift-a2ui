# ``A2UIParser``

LLM のストリーミングレスポンスから A2UI JSON ブロックをリアルタイムに抽出するパーサーモジュール。

## Overview

`A2UIParser` は LLM が生成するテキストストリームを受け取り、その中に埋め込まれた A2UI JSON ペイロードをリアルタイムで検出・デコードする。LLM はプレーンテキストと JSON を混在させて出力することがあるため、このモジュールがストリームを監視して A2UI メッセージ部分だけを取り出す。

`A2UIStreamingParser` はチャンクごとにテキストを受け取るステートフルなパーサー。各チャンクを渡すと `A2UIResponsePart` の配列として「テキスト断片」または「解析済み A2UI メッセージ」が返る。`A2UIBlockParser` は完結した文字列から A2UI ブロック全体をパースするステートレスな関数集合。

`JSONSanitizer` は LLM が生成する不完全な JSON（末尾カンマ・コメント・エスケープ崩れなど）を修復し、パース成功率を高める。`A2UIPayloadFixer` は意味レベルの補正（欠落フィールドのデフォルト補完など）を担う。

```swift
import A2UIParser

let parser = A2UIStreamingParser()

// LLM からチャンクが届くたびに呼び出す
for chunk in llmChunks {
    let parts = parser.feed(chunk)
    for part in parts {
        if let text = part.text {
            print("テキスト:", text)
        }
        if let messages = part.messages {
            print("A2UI メッセージ:", messages)
        }
    }
}
let finalParts = parser.finalize()
```

## Topics

### ストリーミングパーサー

- ``A2UIStreamingParser``
- ``A2UIResponsePart``

### ブロックパーサー

- ``A2UIBlockParser``

### JSON 修復

- ``JSONSanitizer``
- ``A2UIPayloadFixer``
