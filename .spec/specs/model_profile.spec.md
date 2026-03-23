# Model Profile

Current-truth descriptive model-facts contract for ReqLlmNext 2.0.

```spec-meta
id: reqllm.model_profile
kind: model_profile
status: active
summary: Canonical descriptive model facts and execution-surface catalog.
surface:
  - specs/model_profile.md
  - specs/execution_surface.md
  - specs/architecture.md
decisions:
  - reqllm.decision.profile_descriptive_not_prescriptive
  - reqllm.decision.execution_surface_support_unit
```

## Requirements

```spec-requirements
- id: reqllm.model_profile.descriptive_facts
  statement: ReqLlmNext shall normalize resolved model metadata into a request-independent `ModelProfile` that describes operations, features, modalities, limits, parameter defaults, constraints metadata, and session capabilities without choosing concrete request behavior.
  priority: must
  stability: evolving

- id: reqllm.model_profile.execution_surfaces_declared
  statement: `ModelProfile` shall declare explicit named `ExecutionSurface` entries for supported endpoint styles instead of implying support from independent protocol, wire-format, and transport lists.
  priority: must
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: specs/model_profile.md
  covers:
    - reqllm.model_profile.descriptive_facts
    - reqllm.model_profile.execution_surfaces_declared
```
