---
id: reqllm.decision.execution_surface_support_unit
status: accepted
date: 2026-03-22
affects:
  - reqllm.architecture
  - reqllm.model_profile
  - reqllm.execution_surfaces
  - reqllm.execution_plan
---

# ExecutionSurface Is the Unit of Endpoint Support

## Context

ReqLlmNext needs to support multiple endpoint styles for the same provider and sometimes for the same model. Treating semantic protocol, wire format, and transport as separate lists suggests a free cartesian product of combinations that real provider APIs do not actually support.

For example, one API family may be available over both HTTP/SSE and WebSocket, but with different wire envelopes, session compatibility, and fallback behavior.

## Decision

ReqLlmNext 2.0 uses named `ExecutionSurface` entries as the stable support unit for endpoint styles.

Each `ExecutionSurface` bundles:

1. one operation family
2. one semantic protocol
3. one wire format
4. one transport
5. session compatibility
6. feature tags and modality support relevant to that endpoint style

`ModelProfile` declares the surfaces a model supports, and planning chooses among those declared surfaces.

Surface ids are source-owned. They are selected from a bounded registry keyed
by declared surface prefix, operation, and transport rather than assembled from
provider, model, fixture, or generated input. Unknown tuples fail closed before
profile construction.

## Consequences

Support is explicit and easier to inspect, test, and override.

Fallback planning becomes more coherent because the system falls back from one named surface to another rather than recomputing combinations from independent lists.

Adding a new endpoint style usually means adding a new surface plus the matching layer implementations instead of overloading existing metadata fields.

The registry gives source policy a concrete boundary: adding a new endpoint
style requires adding the named surface and its registry entry in source, with
tests for both accepted and unknown tuples.
