# ``A2UIAgentTool``

The `send_a2ui_json_to_client` tool an A2UI agent hands to an LLM, plus the extractor that reads its result.

> **Unofficial.** Not affiliated with or endorsed by the authors of the A2UI protocol. Conforming to the specification is not a goal of this project.

## Overview

`A2UIAgentTool` is the Swift implementation of `send_a2ui_json_to_client`, the tool through which an A2UI agent lets an LLM render and update UI on the client. It corresponds to the Python SDK's `a2ui.adk` module.

`SendA2UIToClientTool<Catalog>` conforms to the tool protocol and is generic over the catalog, which binds the renderable component set at compile time. It produces the tool definition (name, description, argument schema) and carries its own schema block and worked examples into the system prompt when it is attached. When a call arrives it reads the `a2ui_json` argument — tolerating models that pass raw JSON where the contract asks for a stringified array — parses and repairs the payload, then validates it against the catalog and against the same allowlists the prompt was pruned by.

What a caller gets back is one of two things. A valid payload returns as a JSON result whose `validated_a2ui_json` key holds the decoded `AgentMessage` array, and, because this is a turn-ending tool, the turn finishes without further inference. Anything that fails to parse or validate returns as a tool error carrying the reason, which the model reads and corrects within the same loop; nothing unvalidated reaches the renderer.

`A2UIToolResultExtractor` is the other end of that contract: it pulls the `AgentMessage` values out of a tool result for an orchestrator to forward. It answers `nil` for error results and for other tools' results, which is how a failed generation is kept off the user's screen.

```swift
import A2UIAgentTool
import A2UICatalog
import A2UIPrompt
import A2UITyped
import LLMTool

// A tool restricted to BasicCatalog, offering the whole basic palette.
// Narrow `allowedComponents` and the prompt shrinks with it: the model is
// only shown what it is allowed to send.
let tool = SendA2UIToClientTool<BasicCatalog>(
    promptBuilder: A2UIPromptBuilder(
        agentToRendererSchema: nil,
        commonTypesSchema: nil,
        catalogSchema: nil,
        allowedComponents: BasicComponent.componentNames,
        allowedMessages: nil
    )
)
let tools: [any Tool] = [tool]
```

## Topics

### Tool definition

- ``SendA2UIToClientTool``

### Reading tool results

- ``A2UIToolResultExtractor``
