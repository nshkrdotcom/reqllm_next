# Model Input Boundary Spec

Status: Proposed

<!-- covers: reqllm.architecture.model_input_boundary -->

## Objective

Define the public model input contract so ReqLlmNext accepts only `LLMDB` `model_spec` strings and `%LLMDB.Model{}` values through the runtime API.

## Purpose

This is a strict runtime boundary. Public model input is treated like untrusted configuration and must be validated before execution.

`ModelSource` is an internal normalization artifact, not a public API type. Public APIs accept `model_input`; the boundary may materialize `ModelSource` internally while constructing a `ModelProfile`.

## Accepted Public Input Forms

ReqLlmNext public APIs must accept any of the following as a model spec:

1. `LLMDB` `model_spec` string
   - Examples: `"openai:gpt-5.4"` or `"gpt-5.4@openai"`

2. `%LLMDB.Model{}`
   - Either a resolved catalog model struct or a handcrafted local model struct that satisfies the `LLMDB.Model` shape

## Boundary Behavior

The public API accepts two model input forms, but the system must treat them as input only.

After this boundary:

1. raw model input is discarded
2. execution code does not branch on `%LLMDB.Model{}`
3. the system works from a validated canonical profile

## Validation and Normalization Contract

The boundary must reject any runtime model input that is not:

1. a binary `model_spec`
2. an `%LLMDB.Model{}`

For binary specs:

1. resolve through `LLMDB.model/1`
2. let `LLMDB` own string parsing, alias resolution, provider normalization, and provider-specific model-spec edge cases
3. preserve the original string for diagnostics
4. fail immediately if the spec does not resolve

For `%LLMDB.Model{}` input:

1. treat the struct as an accepted model boundary object, whether catalog-resolved or handcrafted
2. preserve provider and model id for downstream profile construction
3. allow local iteration with models not yet present in `LLMDB`
4. still apply canonical profile validation after normalization

All accepted public forms are normalized into a canonical `ModelSource`.

```elixir
%ModelSource{
  kind: :model_spec | :llmdb_struct,
  source: :llmdb,
  provider: :openai,
  id: "gpt-5.4",
  raw: term()
}
```

## Resolution Rules

1. String `model_spec` values resolve through `LLMDB`.
2. ReqLlmNext must not reimplement `model_spec` parsing rules that already belong to `LLMDB`.
3. `%LLMDB.Model{}` values are treated as accepted model boundary objects and are not required to have been loaded from the current `LLMDB` snapshot.

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
2. Family and model-id overrides apply to any accepted normalized model identity, whether it came from a `model_spec` or a handcrafted `%LLMDB.Model{}`.
3. A provided `%LLMDB.Model{}` should receive the same override treatment as the equivalent resolved `model_spec` when identities match.

## Local Iteration Rule

Supporting `%LLMDB.Model{}` directly is a deliberate developer-experience hook.

It enables:

1. local iteration on unreleased models before catalog updates land
2. testing provider behavior without first changing `LLMDB`
3. local-provider development such as Ollama-style integrations

This flexibility exists at the struct boundary only. ReqLlmNext still rejects ad hoc maps, tuples, or local descriptor types.

## What Does Not Belong Here

1. local descriptor structs or naked maps
2. request-scoped options such as `temperature`
3. live session handles
4. encoded HTTP or WebSocket payloads
5. provider auth tokens
