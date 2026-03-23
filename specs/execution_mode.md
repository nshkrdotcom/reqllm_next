# Execution Mode Spec

Status: Proposed

<!-- covers: reqllm.execution_mode.normalized_shape reqllm.execution_mode.mode_hints_before_policy -->

## Objective

Define the canonical request-mode object that normalizes endpoint-selection intent before policy rules run.

## Purpose

`ExecutionMode` captures the parts of a request that influence:

1. surface selection
2. session strategy
3. timeout class
4. fallback policy

It is not the same thing as generation parameters.

## Canonical Shape

```elixir
%ExecutionMode{
  operation: :text | :object | :embedding,
  stream?: boolean(),
  tools?: boolean(),
  structured_output?: boolean(),
  session: :none | :preferred | :required | :continue,
  latency_class: :interactive | :background | :long_running,
  reasoning: :default | :off | :on | :required,
  conversation: :single_turn | :multi_turn,
  input_modalities: [:text] | [:text, :image] | [...]
}
```

## Normalization Rule

`ExecutionMode` must be normalized before policy rules run.

The planner should derive it from:

1. public API intent
2. presence of tools or schema output
3. context shape
4. explicit session and latency hints
5. input modalities

## Request Decomposition Rule

Public request input splits into:

1. mode hints
   - contribute to `ExecutionMode`
   - examples: `stream?`, session preference, structured output, tool usage, latency class

2. generation parameters
   - stay outside `ExecutionMode`
   - examples: `temperature`, `max_output_tokens`, `top_p`, `stop`

This split is important because mode drives surface selection, while generation parameters are normalized after the surface is chosen.

## Invariants

1. `ExecutionMode` must be provider-agnostic.
2. `ExecutionMode` must not contain a chosen surface, chosen transport, or chosen protocol.
3. `ExecutionMode` must not contain raw tool definitions or encoded payloads.
4. `ExecutionMode` must be serializable and inspectable for diagnostics.

## Example

For a tool-heavy coding request against `openai:gpt-5-codex`, the normalized mode might be:

```elixir
%ExecutionMode{
  operation: :text,
  stream?: true,
  tools?: true,
  structured_output?: false,
  session: :preferred,
  latency_class: :long_running,
  reasoning: :on,
  conversation: :multi_turn,
  input_modalities: [:text]
}
```
