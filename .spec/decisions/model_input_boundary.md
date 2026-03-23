---
id: reqllm.decision.model_input_boundary
status: accepted
date: 2026-03-22
affects:
  - reqllm.architecture
  - reqllm.package
---

# Narrow Public Model Input Boundary

## Context

The early spike allowed several public model-input shapes, including tuples and proposed local descriptors.

That flexibility made the runtime boundary blurry. Public APIs could accept shapes that only existed for spike convenience, and `LLMDB.model/1` could quietly absorb forms that the 2.0 runtime should no longer promise.

For ReqLlmNext 2.0, the user direction is to keep the public runtime surface small and explicit while still allowing either late resolution from a registry string or direct reuse of an already-resolved `%LLMDB.Model{}`.

## Decision

ReqLlmNext runtime APIs accept model input in only two forms:

1. a registry spec string such as `"openai:gpt-5.4"`
2. an `%LLMDB.Model{}`

Tuple forms, local structs, and naked maps are not part of the 2.0 runtime contract.

`%LLMDB.Model{}` remains a valid public input for tests, tooling, and callers that already hold resolved registry metadata, but execution code must still normalize away raw model structs before deeper planning and execution.

## Consequences

The public API contract is easier to explain, test, and enforce.

`ModelResolver` becomes the hard gate for supported runtime input types, and tuple-style model forms now fail immediately instead of flowing through `LLMDB.model/1`.

If we later want local model experimentation again, it should return as a separate, explicit capability with its own ADR and boundary rules rather than as implicit public runtime flexibility.
