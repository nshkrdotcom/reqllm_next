---
id: reqllm.decision.five_scope_policy_rules
status: accepted
date: 2026-03-22
affects:
  - reqllm.architecture
  - reqllm.policy_rules
  - reqllm.execution_plan
---

# Policy Resolution Uses Five Ordered Scopes

## Context

The spike architecture relies on provider, family, model, and request-time behavior in ways that are not clearly separated. That is not enough to express the main 2.0 design goal: mode-level overrides for very specific models without turning the planner into a collection of model-name branches.

ReqLlmNext needs a flexible way to say things like:

1. prefer one surface for a provider family in general
2. override that preference for one model
3. override it again for one operation
4. override it again for one mode such as streaming tools with a persistent session

## Decision

ReqLlmNext 2.0 resolves execution policy as ordered declarative rules across five scopes:

1. provider
2. family
3. model
4. operation
5. mode

Rules use a match-and-patch model and may choose or influence:

1. preferred surface
2. fallback surfaces
3. timeout class
4. session defaults
5. stable parameter defaults
6. plan adapter references

Rules may only choose among capabilities and surfaces already declared in `ModelProfile`.

## Consequences

Mode-specific behavior stays declarative and inspectable.

The planner becomes the single owner of policy resolution instead of scattering override logic across constraints, adapters, and protocol code.

Supporting new models often becomes a rule addition rather than a custom code path.
