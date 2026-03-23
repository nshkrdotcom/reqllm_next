# Execution Surface Spec

Status: Proposed

<!-- covers: reqllm.execution_surfaces.support_unit reqllm.execution_surfaces.non_cartesian -->

## Objective

Define the stable support unit for endpoint styles in ReqLlmNext.

## Purpose

An `ExecutionSurface` represents one valid way for one model to perform one operation family.

It bundles:

1. semantic protocol
2. wire format
3. transport
4. session compatibility
5. feature tags relevant to that endpoint style

This is the support unit because real provider APIs do not expose a free cartesian product of protocol, wire format, and transport choices.

## Canonical Shape

```elixir
%ExecutionSurface{
  id: :responses_ws_text,
  operation: :text,
  semantic_protocol: :openai_responses,
  wire_format: :openai_responses_ws_json,
  transport: :websocket,
  session_modes: [:none, :persistent],
  features: %{
    streaming: true,
    tools: true,
    structured_outputs: true
  },
  input_modalities: [:text, :image],
  output_modalities: [:text],
  parameter_profile: :responses_text
}
```

## Non-Cartesian Rule

Support must not be inferred from independent lists such as:

1. supported protocols
2. supported wire formats
3. supported transports

Those lists suggest combinations that may not actually exist.

Instead, the profile must declare explicit named surfaces.

## Selection Rule

The planner chooses exactly one primary surface for an `ExecutionPlan` and may choose additional fallback surfaces.

Rules may prefer or forbid surfaces, but they may only act on surfaces already declared in `ModelProfile`.

## Example

For `openai:gpt-5-codex`, text support might include:

1. `:responses_http_text`
   - Responses API over HTTP/SSE

2. `:responses_ws_text`
   - Responses API over WebSocket with persistent session support

Those are two surfaces, not one protocol with freely mixed transports.
