# Model Profile

Current-truth descriptive model-facts contract for ReqLlmNext 2.0.

<!-- covers: reqllm.model_profile.descriptive_facts reqllm.model_profile.execution_surfaces_declared reqllm.model_profile.request_independent -->

```spec-meta
id: reqllm.model_profile
kind: model_profile
status: active
summary: Canonical descriptive model facts and execution-surface catalog.
surface:
  - lib/req_llm_next/model_profile.ex
  - lib/req_llm_next/model_profile/provider_facts.ex
  - lib/req_llm_next/model_profile/provider_facts/**/*.ex
  - lib/req_llm_next/execution_surface.ex
  - lib/req_llm_next/operation_planner.ex
decisions:
  - reqllm.decision.profile_descriptive_not_prescriptive
  - reqllm.decision.execution_surface_support_unit
```

## Requirements

```spec-requirements
- id: reqllm.model_profile.descriptive_facts
  statement: ReqLlmNext shall normalize resolved model metadata into a request-independent `ModelProfile` that describes operations, features, modalities, limits, parameter defaults, constraints metadata, and session capabilities without choosing concrete request behavior, including manifest-backed provider-scoped descriptive fact extraction for normalized features such as Anthropic structured outputs, citations, context management, and additional document input, plus the resolved extension family id selected by declarative criteria and provider or global fallback rules that owns surface-catalog construction and must declare the catalog module that builds the model's execution surfaces.
  priority: must
  stability: evolving

- id: reqllm.model_profile.execution_surfaces_declared
  statement: `ModelProfile` shall declare explicit named `ExecutionSurface` entries for supported endpoint styles instead of implying support from independent protocol, wire-format, and transport lists, including multiple transport variants for one semantic family when the provider truly supports them.
  priority: must
  stability: evolving

- id: reqllm.model_profile.request_independent
  statement: `ModelProfile` shall remain request-independent, serializable, and safe to cache, and it shall not contain chosen surfaces, prompt state, continuation state, or network handles.
  priority: must
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/model_profile.spec.md
  covers:
    - reqllm.model_profile.descriptive_facts
    - reqllm.model_profile.execution_surfaces_declared
    - reqllm.model_profile.request_independent

- kind: command
  target: mix test test/model_profile_test.exs test/operation_planner_test.exs
  execute: true
  covers:
    - reqllm.model_profile.descriptive_facts
    - reqllm.model_profile.execution_surfaces_declared
```
