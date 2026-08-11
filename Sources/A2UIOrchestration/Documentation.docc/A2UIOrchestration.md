# ``A2UIOrchestration``

Orchestration policy for multi-agent setups: who owns which surface, where a user action goes, and
what data each agent is allowed to see.

> **Unofficial.** Not affiliated with or endorsed by the authors of the A2UI protocol. Conforming to the specification is not a goal of this project.

## Overview

When several subagents render into the same conversation, two questions come up on every turn: which
agent should receive this user action, and which surfaces' data may travel with the message. Both
answers come from one piece of state — a record of which agent created which surface. This module is
that record and nothing else: no UI, no LLM runtime, no I/O.

``SurfaceOwnership`` is a conversation-scoped ledger of surface id to agent name, used three ways.
**Recording** (`record(surfacesCreatedIn:by:)`) observes a subagent's response and claims the
surfaces it created. **Deterministic routing** (`owner(ofUserActionIn:)`) reads the `surfaceId` off a
`UserAction` and names the owning agent, skipping an LLM round trip; returning `nil` means fall back
to LLM routing, so this is an optimization and never a correctness gate. **Data model narrowing**
(`outboundMetadata(_:capabilities:for:)`) is the one that is not optional — it strips the client data
model down to the surfaces the recipient owns, which is what prevents one agent from reading
another's surface data. Assemble agent-bound metadata through that function rather than around it.

The ledger is a value type, so the host runtime holds it as session state and updates it in place.
Keep it scoped to a single conversation: carried across conversations, a stale surface id decides
both where a message is routed and what data goes with it. Ownership is last-write-wins, matching the
official sample's overwrite semantics.

```swift
import A2UIOrchestration
import A2UIA2A
import A2ACore

var ownership = SurfaceOwnership()

// When a subagent's response comes back
ownership.record(surfacesCreatedIn: responseParts, by: "a2ui")

// Routing the next user message
if let agent = ownership.owner(ofUserActionIn: userParts) {
    // Route straight there, without going through the LLM
    await sendTo(agent: agent, parts: userParts)
}

// Narrow the metadata sent to a subagent
let outgoing = try ownership.outboundMetadata(
    metadata, capabilities: caps, for: "a2ui"
)
```

## Topics

### Surface ownership

- ``SurfaceOwnership``
