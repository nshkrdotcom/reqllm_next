# Execution Plan Spec

Status: Proposed

<!-- covers: reqllm.execution_plan.prescriptive_object reqllm.execution_plan.surface_and_fallbacks reqllm.execution_plan.deterministic_stack -->

## Objective

Define the single prescriptive object that downstream execution layers consume for one request attempt.

## Purpose

`ExecutionPlan` is the only object that should answer:

1. how this request will run
2. which surface it will use
3. which parameters are normalized
4. which fallbacks are allowed
5. which adapters apply

Everything before the plan is descriptive or declarative. Everything after the plan executes what it says.

## Canonical Shape

```elixir
%ExecutionPlan{
  model: %ModelProfile{},
  mode: %ExecutionMode{},
  surface: %ExecutionSurface{id: :responses_ws_text, ...},
  provider: :openai,
  semantic_protocol: :openai_responses,
  wire_format: :openai_responses_ws_json,
  transport: :websocket,
  parameter_values: %{
    max_output_tokens: 16_000,
    reasoning_effort: :high
  },
  timeout_class: :long_running,
  timeout_ms: 300_000,
  session_strategy: %{
    mode: :attach_or_create,
    continuation: :previous_response_id
  },
  fallback_surfaces: [
    :responses_http_text
  ],
  plan_adapters: [
    ReqLlmNext.Adapters.OpenAI.Reasoning
  ]
}
```

## Invariants

1. `ExecutionPlan` must reference exactly one chosen primary surface.
2. The chosen surface must exist in `ModelProfile`.
3. Fallback surfaces must also exist in `ModelProfile`.
4. All generation parameters in the plan must already be normalized against constraints.
5. Downstream layers must not perform their own independent surface selection.
6. For the same `ModelProfile`, `ExecutionMode`, and policy set, plan assembly must be deterministic.
7. A plan must resolve one implementation stack tuple: provider, session runtime mode, semantic protocol, wire format, transport, and ordered plan adapters.

## Prescriptive Rule

`ExecutionPlan` is the only prescriptive runtime object.

That means:

1. `ModelProfile` describes support
2. `ExecutionMode` describes request intent
3. policy rules describe preferences
4. `ExecutionPlan` records the final decision

## Deterministic Stack Rule

The plan must fully determine the execution implementation.

That means downstream execution must not:

1. remap the surface to a different protocol or transport
2. discover extra adapters by model name
3. reinterpret the model to choose different layer modules

If a model needs special handling, that handling must enter through declared surfaces, matching policy rules, or explicit plan-adapter refs so it stays isolated to the matching plan rather than leaking into other models.

## Example

For a streaming, tool-heavy, session-oriented coding request:

1. `ModelProfile` declares both HTTP and WebSocket Responses surfaces
2. `ExecutionMode` expresses streaming, tools, and session preference
3. policy rules prefer WebSocket for this mode
4. `ExecutionPlan` records `:responses_ws_text` as primary and `:responses_http_text` as fallback
