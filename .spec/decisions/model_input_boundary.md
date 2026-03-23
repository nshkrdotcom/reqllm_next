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

For ReqLlmNext 2.0, the user direction is to keep the public runtime surface small and explicit while still allowing either late resolution from an `LLMDB` `model_spec` string or direct reuse of an already-resolved `%LLMDB.Model{}`.

## Decision

ReqLlmNext runtime APIs accept model input in only two forms:

1. an `LLMDB` `model_spec` string such as `"openai:gpt-5.4"` or `"gpt-5.4@openai"`
2. an `%LLMDB.Model{}`

Tuple forms, local structs, and naked maps are not part of the 2.0 runtime contract.

`%LLMDB.Model{}` remains a valid public input for tests, tooling, and callers that already hold resolved registry metadata, and it is also the explicit developer-experience hook for handcrafted local models. This breaks the old coupling where trying a new model required defining it in `LLMDB` first.

That means local iteration, unreleased-model support, and local-provider work such as Ollama may start from a handcrafted `%LLMDB.Model{}` as long as the struct shape is valid. Execution code must still normalize away raw model structs before deeper planning and execution.

## Consequences

The public API contract is easier to explain, test, and enforce.

ReqLlmNext delegates string parsing semantics to `LLMDB`, so advanced `model_spec` behavior such as alias resolution, filename-safe `@` format, and provider-specific parsing rules stay owned by the catalog package instead of being reimplemented locally.

`ModelResolver` becomes the hard gate for supported runtime input types, and tuple-style model forms now fail immediately instead of flowing through `LLMDB.model/1`.

This preserves a narrow boundary without forcing all experimentation through catalog changes first. ReqLlmNext stays strict about accepted types while still giving developers a practical local iteration path.
