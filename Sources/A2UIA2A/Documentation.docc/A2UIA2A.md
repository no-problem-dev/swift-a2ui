# ``A2UIA2A``

Carries A2UI over A2A: part coding, the metadata vocabulary, and the agent card declaration.

> **Unofficial.** Not affiliated with or endorsed by the authors of the A2UI protocol. Conforming to the specification is not a goal of this project.

## Overview

`A2UIA2A` integrates A2UI with the A2A (Agent-to-Agent) protocol, matching the Python SDK's
`a2ui.a2a` module. A2UI messages travel as A2A `Part` values tagged with the media type
`application/a2ui+json`, and this module does the tagging, the detection and the decoding.

``A2UIMediaType`` holds that media type along with the metadata key the v0.x Python SDK tagged
with. The extensions on `Part` — `Part.a2ui(_:)`, `part.a2uiAgentMessage()`,
`part.a2uiRendererMessage()`, `part.a2uiUserAction` — hang directly off A2A's own `Part` type.
They accept either tag position on decode but always write the modern one, so a Swift agent
interoperates with an older Python peer without configuration.

Extraction over a sequence of parts or a stream event (`a2uiAgentMessages()`, `containsA2UI`) is
deliberately lenient: a part that claims A2UI but does not decode is dropped rather than raised,
so one malformed part cannot stall rendering. When the difference between "no A2UI" and "broken
A2UI" matters, call `a2uiAgentMessage()` on the part yourself and catch the error.

``A2UIExtension`` builds the A2UI declaration for an A2A AgentCard (`agentExtension(supportedCatalogIds:)`)
and reads declarations back off a remote card (`declarations(in:)`, `currentDeclaration(in:)`).
``A2UIMessageMetadata`` embeds and extracts client capabilities (``A2UIRendererCapabilities``) and
the client data model (``A2UIRendererDataModel``) in A2A metadata — the channel that keeps catalog
negotiation out of the LLM prompt. Note that v1.0 nests capabilities under a version key but keeps
the data model flat; the accessors absorb that asymmetry.

```swift
import A2UIA2A
import A2UICore

// Turn an AgentMessage into an A2A Part
let message = AgentMessage.createSurface(CreateSurface(
    surfaceId: "main",
    catalogId: BasicComponentCatalog.catalogId
))
let part = try Part.a2ui(message)

// Take the A2UI message back out of a received Part
if let serverMsg = try receivedPart.a2uiAgentMessage() {
    print("received:", serverMsg)
}
```

## Topics

### Part coding

- ``A2UIMediaType``

### Agent card declaration

- ``A2UIExtension``

### Message metadata

- ``A2UIMessageMetadata``
- ``A2UIRendererCapabilities``
- ``A2UIRendererDataModel``
