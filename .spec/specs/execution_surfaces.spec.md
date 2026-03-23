# Execution Surfaces

Current-truth endpoint-style support contract for ReqLlmNext 2.0.

```spec-meta
id: reqllm.execution_surfaces
kind: execution_surface
status: active
summary: Explicit named execution surfaces as the support unit for endpoint styles.
surface:
  - specs/execution_surface.md
  - specs/model_profile.md
  - specs/architecture.md
decisions:
  - reqllm.decision.execution_surface_support_unit
```

## Requirements

```spec-requirements
- id: reqllm.execution_surfaces.support_unit
  statement: ReqLlmNext shall represent each valid endpoint style as a named `ExecutionSurface` that bundles semantic protocol, wire format, transport, session compatibility, and feature tags for one operation family.
  priority: must
  stability: evolving

- id: reqllm.execution_surfaces.non_cartesian
  statement: ReqLlmNext shall not infer endpoint support from a cartesian product of independent protocol, wire-format, and transport lists and shall instead resolve only declared execution surfaces.
  priority: must
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: specs/execution_surface.md
  covers:
    - reqllm.execution_surfaces.support_unit
    - reqllm.execution_surfaces.non_cartesian
```
