---
id: reqllm.decision.layer_scoped_plan_aware_adapters
status: accepted
date: 2026-03-22
affects:
  - reqllm.architecture
  - reqllm.policy_rules
  - reqllm.layer_boundaries
---

# Adapters Are Layer-Scoped and Plan-Aware

## Context

The spike adapter pipeline operates on raw `%LLMDB.Model{}` values and request options before planning. That makes it difficult to express narrow model quirks without also letting adapters bypass architectural boundaries.

It also prevents adapters from seeing the resolved surface, session strategy, or fallback behavior that often matters for the quirks we actually need to support.

## Decision

ReqLlmNext 2.0 treats adapters as explicit, layer-scoped extension points instead of a global mutation pipeline.

The initial adapter form is `PlanAdapter`, which patches `ExecutionPlan` after policy resolution.

If future work introduces protocol-level or wire-format-level adapters, they must remain separate behaviors with explicit ownership. ReqLlmNext should not reintroduce an omniscient adapter stage that can reach across all layers at once.

## Consequences

Imperative customizations stay small and easier to reason about.

Most model-specific behavior should move into profile facts and policy rules, leaving adapters for the cases that truly require code.

When an adapter is necessary, it can make decisions with full visibility into the chosen surface and resolved plan instead of guessing from raw model metadata.
