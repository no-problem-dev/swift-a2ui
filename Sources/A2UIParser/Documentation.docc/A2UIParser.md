# ``A2UIParser``

Recovers A2UI messages from the text an LLM actually produced, including the malformed shapes.

> **Unofficial.** Not affiliated with or endorsed by the authors of the A2UI protocol. Conforming to the specification is not a goal of this project.

## Overview

A model asked for A2UI JSON does not reliably return only A2UI JSON. It wraps the payload in a
code fence, adds `// comments`, leaves a trailing comma, types smart quotes, writes LaTeX with
single backslashes, or ignores the tool contract and puts the JSON in its chat text. This module
is where those shapes are absorbed, so that a disobeyed instruction does not become raw JSON on
the user's screen.

There are two temperaments here, and choosing between them is the main decision a caller makes.
``A2UIBlockParser``, ``A2UIStreamingParser`` and ``A2UITextSalvage`` are lenient: they keep
whatever decodes and silently discard whatever does not, because a half-rendered surface beats no
surface. ``A2UIPayloadFixer`` is strict: when the payload arrives as a tool argument the model is
still in the loop, so a payload that will not decode throws and the error goes back as a tool
error for the model to correct.

``JSONSanitizer`` performs the repairs common to both — smart quotes, fences, comments, trailing
commas. Only comment stripping is string-aware; the other steps rewrite the whole document,
string values included. ``A2UIPayloadFixer`` adds one more repair on top, doubling backslashes
that do not begin a valid JSON escape, which is what makes LaTeX-heavy content decode.

``A2UIStreamingParser`` is the incremental front end: feed it chunks and it emits each
`<a2ui-json>` block as soon as the closing tag arrives. It withholds text until a block completes,
so `finalize()` is mandatory — a response with no block at all yields nothing until it is called.

```swift
import A2UIParser

let parser = A2UIStreamingParser()

// Call as each chunk arrives from the LLM
for chunk in llmChunks {
    let parts = parser.feed(chunk)
    for part in parts {
        if let text = part.text {
            print("text:", text)
        }
        if let messages = part.messages {
            print("A2UI messages:", messages)
        }
    }
}
let finalParts = parser.finalize()
```

## Topics

### Streaming

- ``A2UIStreamingParser``
- ``A2UIResponsePart``

### Whole-response parsing

- ``A2UIBlockParser``

### Repairing malformed output

- ``JSONSanitizer``
- ``A2UIPayloadFixer``
- ``A2UITextSalvage``
