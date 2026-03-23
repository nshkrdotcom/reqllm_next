# Policy Rules

Current-truth rule-resolution and adapter-boundary contract for ReqLlmNext 2.0.

```spec-meta
id: reqllm.policy_rules
kind: policy_rules
status: active
summary: Ordered match-and-patch policy rules plus capability-safe adapter references.
surface:
  - specs/overrides.md
  - specs/architecture.md
  - specs/operation_planner.md
decisions:
  - reqllm.decision.five_scope_policy_rules
  - reqllm.decision.layer_scoped_plan_aware_adapters
```

## Requirements

```spec-requirements
- id: reqllm.policy_rules.five_scopes
  statement: ReqLlmNext shall resolve policy as ordered rules across provider, family, model, operation, and mode scopes.
  priority: must
  stability: evolving

- id: reqllm.policy_rules.match_patch
  statement: Policy rules shall use a declarative match-and-patch model to choose preferred surfaces, fallback surfaces, timeout classes, session defaults, stable parameter defaults, and plan adapter references.
  priority: must
  stability: evolving

- id: reqllm.policy_rules.capability_safe
  statement: Policy rules shall only choose among capabilities and execution surfaces already declared in `ModelProfile` and shall not invent unsupported behavior.
  priority: must
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: specs/overrides.md
  covers:
    - reqllm.policy_rules.five_scopes
    - reqllm.policy_rules.match_patch
    - reqllm.policy_rules.capability_safe
```
