# Model Source Spec

Status: Proposed

## Objective

Define the public model-spec input contract so ReqLlmNext can accept production registry models and local development models through the same API.

## Purpose

ReqLlmNext should not require an LLMDB patch for every model iteration. LLMDB remains the preferred production registry, but local model descriptors must be a first-class input for development, testing, and experimentation.

This is a strict runtime boundary. Public model input is treated like untrusted configuration and must be validated before execution.

`ModelSource` is an internal normalization artifact, not a public API type. Public APIs accept `model_input`; the boundary may materialize `ModelSource` internally while constructing a `ModelProfile`.

## Accepted Public Input Forms

ReqLlmNext public APIs must accept any of the following as a model spec:

1. Registry spec string
   - Example: `"openai:gpt-5.4"`

2. `%LLMDB.Model{}`
   - Existing production registry model struct

3. `%ReqLlmNext.Model{}`
   - Proposed lightweight local model struct for ReqLlmNext-owned model definitions

4. Naked map
   - Raw local model descriptor map following the contract below

## Boundary Behavior

The public API may accept many model input forms, but the system must treat them as input only.

After this boundary:

1. raw model input is discarded
2. execution code does not branch on `%LLMDB.Model{}`
3. execution code does not read raw local maps
4. the system works from a validated canonical profile

## Local Descriptor Modes

### 1. Standalone Local Descriptor

Used when no LLMDB base exists or when full metadata is supplied locally.

Required minimum fields:

1. `provider`
2. `id`
3. `operations`
4. `modalities`
5. `defaults.protocol` or enough metadata to infer one

### 2. Overlay Local Descriptor

Used to iterate on top of an existing model.

Required fields:

1. `provider`
2. `id`
3. `extends`

Optional fields:

1. `operations`
2. `features`
3. `modalities`
4. `limits`
5. `defaults`
6. `constraints`
7. `adapters`

The overlay descriptor resolves `extends` first, then deep-merges local fields over the base.

## Canonical Descriptor Shape

```elixir
%{
  provider: :openai,
  id: "gpt-5.4-dev",
  extends: "openai:gpt-5.4",
  operations: %{
    text: %{supported: true, stream: true, protocols: [:openai_responses], transports: [:http_sse, :websocket]},
    object: %{supported: true, stream: true, protocols: [:openai_responses], transports: [:http_sse, :websocket]},
    embedding: %{supported: false}
  },
  features: %{
    tool_calling: %{supported: true, parallel: true},
    structured_outputs: %{supported: true},
    reasoning: %{supported: true}
  },
  modalities: %{input: [:text], output: [:text]},
  limits: %{context: 1_000_000, output: 128_000},
  defaults: %{
    protocol: %{text: :openai_responses, object: :openai_responses, embedding: :openai_embeddings},
    transport: %{text: :http_sse, object: :http_sse, embedding: :http}
  },
  constraints: %{
    token_limit_key: :max_output_tokens
  },
  adapters: [
    ReqLlmNext.Adapters.OpenAI.Reasoning
  ]
}
```

## Validation and Normalization Contract

Local descriptors should be validated with a strict `zoi` schema before profile construction.

That schema must reject:

1. unknown keys
2. unknown operation names
3. unknown feature names
4. invalid protocol names
5. invalid transport names
6. unsupported combinations

Operation names must describe stable operation families such as `:text`, `:object`, and `:embedding`. Request modes such as streaming are expressed as properties of an operation family, not as standalone operation names.

String values may be accepted for local input, but they must be normalized through an allowlisted mapping. User input must never create new atoms.

Normalization then produces a canonical internal source representation.

All accepted public forms are normalized into a canonical `ModelSource`.

```elixir
%ModelSource{
  kind: :registry | :llmdb_struct | :local_struct | :local_map,
  source: :llmdb | :local,
  provider: :openai,
  id: "gpt-5.4-dev",
  extends: "openai:gpt-5.4" | nil,
  raw: term()
}
```

## Resolution Rules

1. String registry specs resolve through LLMDB.
2. `%LLMDB.Model{}` values are treated as resolved registry models.
3. `%ReqLlmNext.Model{}` and naked maps are treated as local sources.
4. If `extends` is present, the base model is resolved first.
5. If `extends` is absent, the local descriptor must supply enough metadata to build a profile.

## Validation Rules

Local model descriptors must fail fast if they do not supply enough information to produce:

1. provider identity
2. model identity
3. operation and feature surface needed for validation
4. default protocol selection
5. transport eligibility

If a local descriptor uses unsupported or unknown fields, normalization fails. There is no best-effort fallback.

## Override Interaction

1. Provider overrides apply to all model sources.
2. Family and model-id overrides apply automatically only to registry-backed sources.
3. Local sources may opt into family/model-id override application explicitly.

## Example: `openai:gpt-5.4-dev`

This should be valid:

```elixir
%{
  provider: :openai,
  id: "gpt-5.4-dev",
  extends: "openai:gpt-5.4",
  defaults: %{
    protocol: %{text: :openai_responses, object: :openai_responses},
    transport: %{text: :websocket, object: :websocket}
  }
}
```

That lets a developer test websocket-only iteration for `gpt-5.4` behavior in ReqLlmNext without patching LLMDB first.

## What Does Not Belong Here

1. request-scoped options such as `temperature`
2. live session handles
3. encoded HTTP or WebSocket payloads
4. provider auth tokens
