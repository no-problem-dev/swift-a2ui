# ``A2UIAGUI``

Carries A2UI surfaces over an AG-UI connection, so an AG-UI client paints agent-authored UI and
sends taps back.

> **Unofficial.** Not affiliated with or endorsed by the authors of the A2UI protocol. Conforming to the specification is not a goal of this project.

## Overview

AG-UI has no A2UI message type of its own, so the transport is a set of conventions layered on
top of generic AG-UI events. This module implements the client half and the server half of those
conventions, matching the upstream `a2ui-middleware` wire contract.

Most of what is here is **strings matched byte for byte**, not prose. ``A2UIAGUIConstants``
holds them in one place: the `ACTIVITY_SNAPSHOT` discriminator, the content key of a paint
snapshot, and the `description` a client uses to declare A2UI support — the middleware
discriminates that one on an exact match, em dash included. Retyping any of them by hand is how
a connection silently stops working.

Three paths make up the contract:

- **Declaring support.** ``A2UISchemaContext`` builds the `RunAgentInput.context` entry that
  says "this client can render catalog X". Send the catalog ID alone by default; attaching the
  component schemas is for the case where the server does not know the catalog.
- **Painting.** ``A2UIActivityContent`` and ``A2UISurfaceLifecycle`` model what streams to the
  client while a surface is being generated, on the same message ID as the eventual paint, with
  the paint replacing the progress snapshot.
- **Sending taps back.** ``A2UIAGUIAction`` puts the user action into
  `forwardedProps.a2uiAction` rather than modelling it as a frontend tool, and the server pins
  it into the conversation history.

## Topics

### Wire contract

- ``A2UIAGUIConstants``

### Declaring client support

- ``A2UISchemaContext``

### Painting and progress

- ``A2UIActivityContent``
- ``A2UISurfaceLifecycle``
- ``A2UIGenerationIssue``

### User actions and tools

- ``A2UIAGUIAction``
- ``A2UIRenderTool``
