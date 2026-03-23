# Model Profile Spec

Status: Proposed

<!-- covers: reqllm.model_profile.descriptive_facts reqllm.model_profile.execution_surfaces_declared -->

## Objective

Define the canonical descriptive runtime representation of a model after `llm_db` resolution and static fact patches are applied.

## Purpose

`ModelProfile` is the single source of stable model facts inside ReqLlmNext.

It exists to answer:

1. what this model supports
2. what constraints and defaults are stable facts
3. which execution surfaces exist for this model

It must not answer:

1. which surface this request should use
2. whether this request should be long-running, stateful, or stateless
3. which fallback should be attempted first

Those are planning questions, not profile questions.

## Responsibilities

1. Resolve validated model input into a canonical descriptive profile.
2. Preserve identity, family, operation support, features, modalities, limits, stable parameter defaults, and constraints.
3. Declare supported `ExecutionSurface` entries for each supported operation family.
4. Remain serializable, request-independent, and safe to cache.

## Inputs

1. validated `ModelRef`
2. `llm_db` model metadata
3. static fact patches that alter profile facts without introducing request-specific behavior

## Output Shape

```elixir
%ModelProfile{
  source: :llmdb,
  spec: "openai:gpt-5-codex",
  provider: :openai,
  model_id: "gpt-5-codex",
  family: "gpt-5",
  operations: %{
    text: %{supported: true},
    object: %{supported: true},
    embedding: %{supported: false}
  },
  features: %{
    tools: %{supported: true, parallel: true},
    structured_outputs: %{supported: true},
    reasoning: %{supported: true}
  },
  modalities: %{input: [:text, :image], output: [:text]},
  limits: %{context: 1_000_000, output: 128_000},
  parameter_defaults: %{
    max_output_tokens: 16_000,
    reasoning_effort: :medium
  },
  constraints: %{
    token_limit_key: :max_output_tokens,
    temperature: :unsupported
  },
  session_capabilities: %{
    persistent: true,
    continuation_strategies: [:previous_response_id]
  },
  surfaces: %{
    text: [
      %ExecutionSurface{id: :responses_http_text, ...},
      %ExecutionSurface{id: :responses_ws_text, ...}
    ],
    object: [
      %ExecutionSurface{id: :responses_http_object, ...},
      %ExecutionSurface{id: :responses_ws_object, ...}
    ]
  }
}
```

## Invariants

1. `ModelProfile` must be descriptive only.
2. `ModelProfile` must not contain a preferred surface, selected transport, or selected session strategy for a specific request.
3. `ModelProfile` must not contain prompt text, request options, session handles, or network clients.
4. `ModelProfile` must be validated under a strict schema such as `zoi`.
5. `ModelProfile` must not expose a free-form `capabilities` bag as its primary execution surface.

## Execution Surface Rule

Model support for endpoint styles must be expressed through declared `ExecutionSurface` entries.

The profile must not imply support from independently merged protocol, wire-format, and transport defaults because that suggests invalid cartesian combinations.

Support means:

1. the operation family is supported
2. the named `ExecutionSurface` exists
3. the surface declares the concrete semantic protocol, wire format, and transport combination

## What Belongs Here

1. stable parameter defaults
2. constraints metadata
3. supported surfaces
4. operation-family facts
5. session capability facts

## What Does Not Belong Here

1. per-request `temperature`, `tool_choice`, or timeout overrides
2. selected surface for this request
3. fallback order for this request
4. encoded payloads
5. runtime continuation ids

## Example: `openai:gpt-5-codex`

For `openai:gpt-5-codex`, the profile should say:

1. text and object are supported operation families
2. Responses-over-HTTP and Responses-over-WebSocket are distinct supported surfaces
3. persistent session capability exists
4. reasoning defaults and parameter constraints are stable facts

The profile must not decide whether a tool-heavy coding call should use WebSocket. That is a policy-and-plan decision.
