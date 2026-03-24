# Public API Contract

Current-truth contract for the top-level `ReqLlmNext` facade.

```spec-meta
id: reqllm.public_api
kind: api
status: active
summary: Hard package boundary for the top-level ReqLlmNext API, preserving the v1-style text, object, streaming, embedding, and helper surface while internals evolve.
surface:
  - lib/req_llm_next.ex
  - lib/req_llm_next/anthropic.ex
  - test/public_api/**/*.exs
```

## Requirements

```spec-requirements
- id: reqllm.public_api.hard_surface
  statement: `ReqLlmNext` shall expose the hard package boundary at the top-level facade with `generate_text/3`, `generate_text!/3`, `stream_text/3`, `stream_object/4`, `generate_object/4`, `generate_object!/4`, `embed/3`, `embed!/3`, `model/1`, `provider/1`, `context/1`, `tool/1`, `json_schema/2`, `cosine_similarity/2`, `embedding_models/0`, `put_key/2`, and `get_key/1`.
  priority: must
  stability: evolving

- id: reqllm.public_api.canonical_shapes
  statement: Top-level generation and embedding entrypoints shall accept the canonical public model inputs of `LLMDB` `model_spec` strings or `%LLMDB.Model{}` values, return canonical `Response` or `StreamResponse` values from non-bang forms, and raise from bang forms.
  priority: must
  stability: evolving

- id: reqllm.public_api.thin_facade
  statement: The top-level `ReqLlmNext` module shall remain a thin compatibility facade over the internal planning and execution pipeline rather than accumulating provider, protocol, wire, transport, fixture-specific, or provider-utility branching logic.
  priority: must
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/public_api.spec.md
  covers:
    - reqllm.public_api.hard_surface
    - reqllm.public_api.canonical_shapes
    - reqllm.public_api.thin_facade

- kind: command
  target: mix test test/public_api
  execute: true
  covers:
    - reqllm.public_api.hard_surface
    - reqllm.public_api.canonical_shapes
```
