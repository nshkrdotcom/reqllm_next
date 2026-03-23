# Model Input Boundary Spec

Status: Proposed

<!-- covers: reqllm.architecture.model_input_boundary -->

## Objective

Define the public model-spec input contract so ReqLlmNext accepts only registry model specs and `%LLMDB.Model{}` values through the runtime API.

## Purpose

This is a strict runtime boundary. Public model input is treated like untrusted configuration and must be validated before execution.

`ModelSource` is an internal normalization artifact, not a public API type. Public APIs accept `model_input`; the boundary may materialize `ModelSource` internally while constructing a `ModelProfile`.

## Accepted Public Input Forms

ReqLlmNext public APIs must accept any of the following as a model spec:

1. Registry spec string
   - Example: `"openai:gpt-5.4"`

2. `%LLMDB.Model{}`
   - Existing production registry model struct

## Boundary Behavior

The public API accepts two model input forms, but the system must treat them as input only.

After this boundary:

1. raw model input is discarded
2. execution code does not branch on `%LLMDB.Model{}`
3. the system works from a validated canonical profile

## Validation and Normalization Contract

The boundary must reject any runtime model input that is not:

1. a binary registry spec
2. an `%LLMDB.Model{}`

For binary specs:

1. resolve through `LLMDB.model/1`
2. preserve the original spec for diagnostics
3. fail immediately if the spec does not resolve

For `%LLMDB.Model{}` input:

1. treat the struct as already-resolved registry metadata
2. preserve provider and model id for downstream profile construction
3. still apply canonical profile validation after normalization

All accepted public forms are normalized into a canonical `ModelSource`.

```elixir
%ModelSource{
  kind: :registry_spec | :llmdb_struct,
  source: :llmdb,
  provider: :openai,
  id: "gpt-5.4",
  raw: term()
}
```

## Resolution Rules

1. String registry specs resolve through LLMDB.
2. `%LLMDB.Model{}` values are treated as resolved registry models.

## Validation Rules

Model input must fail fast if:

1. the input is not a binary or `%LLMDB.Model{}`
2. the binary spec does not resolve through LLMDB
3. the normalized source cannot produce provider identity
4. the normalized source cannot produce model identity
5. canonical profile construction fails

There is no best-effort fallback after normalization.

## Override Interaction

1. Provider overrides apply to all model sources.
2. Family and model-id overrides apply to resolved registry models.
3. A provided `%LLMDB.Model{}` should receive the same override treatment as the equivalent resolved registry model.

## What Does Not Belong Here

1. local descriptor structs or naked maps
2. request-scoped options such as `temperature`
3. live session handles
4. encoded HTTP or WebSocket payloads
5. provider auth tokens
