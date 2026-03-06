# Model Profile Spec

Status: Proposed

## Objective

Define the canonical runtime representation of a model after metadata resolution and static overrides are applied.

## Purpose

The `ModelProfile` is the single source of execution truth for a model inside ReqLlmNext. It replaces scattered reads from raw LLMDB metadata, provider modules, and ad hoc model-name checks.

It is built from validated model input, not directly from the public API input.

It is the only model-shaped object that execution code should use.

## Responsibilities

1. Resolve a model spec into a canonical profile.
2. Merge LLMDB metadata with provider, family, and model-id overrides.
3. Expose typed operation families, features, modalities, limits, defaults, constraints metadata, and adapter config.
4. Remain request-independent and serializable.

## Inputs

1. Validated model input
2. Provider override config
3. Family override config
4. Model-id override config when applicable

## Output Shape

```elixir
%ModelProfile{
  source: :llmdb | :local,
  spec: "openai:gpt-5.4",
  provider: :openai,
  model_id: "gpt-5.4",
  family: "gpt-5",
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
  modalities: %{input: [...], output: [...]},
  limits: %{context: 1_000_000, output: 128_000},
  defaults: %{
    protocol: %{text: :openai_responses, object: :openai_responses, embedding: :openai_embeddings},
    transport: %{text: :http_sse, object: :http_sse, embedding: :http},
    timeouts: %{default_ms: 30_000, long_running_ms: 300_000}
  },
  constraints: %{...},
  adapters: [
    ReqLlmNext.Adapters.OpenAI.Reasoning
  ],
  session_policy: %{
    supported: true,
    continuation: :previous_response_id
  }
}
```

The profile shape is closed. Unknown fields must be rejected during profile validation.

The profile must avoid duplicated support facts. Protocol and transport support should live under the relevant operation family. Defaults should express preference, not a second source of support truth.

## Invariants

1. A `ModelProfile` must not contain prompt text, request options, transport handles, or session handles.
2. A `ModelProfile` must be safe to cache.
3. A `ModelProfile` must be stable for the lifetime of a request.
4. A `ModelProfile` must preserve whether it originated from LLMDB or a local descriptor.
5. A `ModelProfile` must be validated under a strict schema such as `zoi`.
6. A `ModelProfile` must not expose a free-form `capabilities` bag as its primary execution surface.
7. Request modes such as streaming must not be modeled as separate top-level operations.

## What Does Not Belong Here

1. Per-request `max_tokens`, `temperature`, or tool choices.
2. Encoded HTTP or WebSocket payloads.
3. Runtime continuation ids such as `previous_response_id`.
4. Network clients, sockets, or PIDs.
5. Raw `%LLMDB.Model{}` metadata.

## Local Model Support

ReqLlmNext must support building a `ModelProfile` from a local model descriptor so developers can iterate on provider/model support before patching LLMDB.

Two local source modes are allowed:

1. Standalone local model
   - supplies enough metadata to build a valid profile without LLMDB

2. Local overlay model
   - declares a base model such as `extends: "openai:gpt-5.4"`
   - resolves the base through LLMDB or another source
   - deep-merges local metadata over the base before profile creation

The local source contract is defined in [model_source.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/model_source.md).

## Example: `openai:gpt-5.4`

For `openai:gpt-5.4`, the `ModelProfile` should say:

1. The text and object operation families use `:openai_responses`.
2. The model supports both stateless and session-aware execution.
3. Allowed transports for text/object include both `:http_sse` and `:websocket`.
4. The model may have reasoning-oriented defaults and larger timeout ranges than `gpt-4o-mini`.

The profile must not decide whether a specific request should use websocket. That decision belongs to the planner.

If `openai:gpt-5.4-dev` is supplied as a local overlay descriptor extending `openai:gpt-5.4`, the resulting profile should preserve `source: :local` while still inheriting the base model's semantic defaults unless explicitly overridden.
