# Execution Surfaces

Current-truth endpoint-style support contract for ReqLlmNext 2.0.

<!-- covers: reqllm.execution_surfaces.support_unit reqllm.execution_surfaces.non_cartesian reqllm.execution_surfaces.surface_selection reqllm.execution_surfaces.transport_variants -->

```spec-meta
id: reqllm.execution_surfaces
kind: execution_surface
status: active
summary: Explicit named execution surfaces as the support unit for endpoint styles.
surface:
  - lib/req_llm_next/execution_surface.ex
  - lib/req_llm_next/model_profile.ex
  - lib/req_llm_next/operation_planner.ex
decisions:
  - reqllm.decision.execution_surface_support_unit
```

## Requirements

```spec-requirements
- id: reqllm.execution_surfaces.support_unit
  statement: ReqLlmNext shall represent each valid endpoint style as a named `ExecutionSurface` that bundles semantic protocol, wire format, transport, session compatibility, and feature tags for one operation family, including provider-native structured-output strategies and provider-native request-preparation rules declared on an existing semantic family such as Anthropic Messages.
  priority: must
  stability: evolving

- id: reqllm.execution_surfaces.non_cartesian
  statement: ReqLlmNext shall not infer endpoint support from a cartesian product of independent protocol, wire-format, and transport lists and shall instead resolve only declared execution surfaces through family-owned surface catalog modules selected by the compiled extension manifest and defined in explicit provider or family definition packs.
  priority: must
  stability: evolving

- id: reqllm.execution_surfaces.surface_selection
  statement: The planner shall choose exactly one primary `ExecutionSurface` for an `ExecutionPlan`, may only choose fallback surfaces already declared in `ModelProfile`, and shall apply explicit compatibility checks for transport, structured output, tools, reasoning, streaming, and session semantics before selecting the highest-ranked matching surface for the active mode.
  priority: must
  stability: evolving

- id: reqllm.execution_surfaces.transport_variants
  statement: ReqLlmNext may declare multiple transport variants for one semantic protocol family, such as OpenAI Responses over HTTP SSE and WebSocket, and explicit transport preference shall only select among those declared surfaces and fallbacks.
  priority: should
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/execution_surfaces.spec.md
  covers:
    - reqllm.execution_surfaces.support_unit
    - reqllm.execution_surfaces.non_cartesian
    - reqllm.execution_surfaces.surface_selection

- kind: command
  target: mix test test/operation_planner_test.exs
  execute: true
  covers:
    - reqllm.execution_surfaces.support_unit
    - reqllm.execution_surfaces.surface_selection
    - reqllm.execution_surfaces.transport_variants
```
