# ``A2UISubagent``

Generates A2UI surfaces from a dedicated sub-agent, so the main model never sees the UI schema
and cannot leak JSON into its prose.

> **Unofficial.** Not affiliated with or endorsed by the authors of the A2UI protocol. Conforming to the specification is not a goal of this project.

## Overview

Asking one model to both hold a conversation and emit correct A2UI JSON goes wrong in a
predictable way: the schema bloats the system prompt, and sooner or later the JSON appears in
the assistant's message body instead of in a tool call. This module splits the job in two.

The planner gets ``GenerateA2UITool`` — one tool, one argument, `intent`. It carries no A2UI
JSON and no schema, so the planner can express nothing more specific than "render some UI".
The actual generation runs as a second LLM request whose only tool is ``RenderA2UITool``,
pinned with `toolChoice`. Answering in prose is not available to that request at the provider
API level, which turns "wrote the JSON into the message body" from rare into impossible.

``A2UISubagentRunner`` drives that inner request with validation-driven retries. Each attempt
rebuilds the prompt from the base string plus the current problems, so fix-it blocks never
stack up; an attempt that validated is never retried; and exhausting the budget returns an
empty result the caller reports back as a tool error rather than as silence.

``A2UISubagentPrompt`` assembles the sub-agent's system prompt, embedding the catalog as text
rather than as tool JSON Schema — the catalog is only known at runtime and a large union hits
provider schema limits. ``A2UIGuidelines`` lets a host replace or suppress individual guideline
blocks without rewriting the whole prompt.

## Topics

### Tools

- ``GenerateA2UITool``
- ``RenderA2UITool``
- ``RenderA2UIArguments``

### Running the sub-agent

- ``A2UISubagentRunner``
- ``A2UISubagentResult``
- ``A2UIAttemptRecord``

### Prompt assembly

- ``A2UISubagentPrompt``
- ``A2UIGuidelines``
- ``A2UIGuidelineBlock``
- ``A2UIDefaultGuidelines``

### Reading results

- ``A2UIOperationsExtractor``
- ``A2UISubagentConstants``
