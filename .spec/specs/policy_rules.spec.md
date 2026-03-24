# Policy Rules

Current-truth rule-resolution and adapter-boundary contract for ReqLlmNext 2.0.

<!-- covers: reqllm.policy_rules.five_scopes reqllm.policy_rules.match_patch reqllm.policy_rules.capability_safe reqllm.policy_rules.allowed_patch_domains -->

```spec-meta
id: reqllm.policy_rules
kind: policy_rules
status: active
summary: Ordered match-and-patch policy rules plus capability-safe adapter references.
surface:
  - lib/req_llm_next/policy_rules.ex
  - lib/req_llm_next/operation_planner.ex
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
  statement: Policy rules shall use a declarative match-and-patch model to choose preferred surfaces, fallback surfaces, timeout classes, session defaults, stable parameter defaults, and plan adapter references, with explicit transport preference remaining authoritative when matching surfaces are available.
  priority: must
  stability: evolving

- id: reqllm.policy_rules.capability_safe
  statement: Policy rules shall only choose among capabilities and execution surfaces already declared in `ModelProfile` and shall not invent unsupported behavior.
  priority: must
  stability: evolving

- id: reqllm.policy_rules.allowed_patch_domains
  statement: Policy rules may patch preferred and fallback surfaces, timeout classes, session defaults, stable parameter defaults for the active mode, and plan-adapter references, but they shall not patch model identity, provider identity, unsupported operations, raw payloads, or provider-specific utility endpoint behavior.
  priority: must
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/policy_rules.spec.md
  covers:
    - reqllm.policy_rules.five_scopes
    - reqllm.policy_rules.match_patch
    - reqllm.policy_rules.capability_safe
    - reqllm.policy_rules.allowed_patch_domains

- kind: command
  target: mix test test/operation_planner_test.exs
  execute: true
  covers:
    - reqllm.policy_rules.five_scopes
    - reqllm.policy_rules.match_patch
```
