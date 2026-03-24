---
id: reqllm.decision.execution_plan_bridge
status: accepted
date: 2026-03-23
affects:
  - reqllm.architecture
  - reqllm.package
  - reqllm.workflow
---

# Introduce a Deterministic Planning Spine Before Rewriting Execution Layers

## Context

ReqLlmNext already had working provider, fixture, and scenario machinery, but the spike execution path still selected provider and wire behavior directly from the raw `%LLMDB.Model{}` during execution.

That made it difficult to move the implementation toward the documented v2 architecture without first rewriting every downstream module in one pass.

## Decision

ReqLlmNext introduces a deterministic planning spine before the full execution-layer split is complete.

The runtime must:

1. build `ModelProfile` from resolved model facts
2. normalize request intent into `ExecutionMode`
3. select explicit `ExecutionSurface` support through policy
4. materialize an `ExecutionPlan`
5. drive provider, semantic protocol, wire, transport, and response-materialization modules from that plan

The lower execution layers are no longer allowed to choose request behavior independently. They resolve runtime modules, request preparation, and normalization from the plan-driven seams instead.

## Consequences

The planner becomes the single place where request behavior is selected, which lets the package harden toward the documented v2 architecture without requiring a flag day rewrite of every lower layer.

That includes two practical rules in the bridge stage:

1. explicit transport preference must be resolved in planning rather than bypassed later by surface-order accidents
2. surface-specific parameter incompatibilities must fail or normalize in the planning boundary rather than being silently patched in wire code
3. provider-native descriptive facts must feed the shared `ModelProfile` through provider-scoped extraction rather than through Anthropic- or OpenAI-specific helper branches in generic code
4. provider-native request preparation must happen in planner-owned surface preparation rather than in shared executor branching after plan assembly

Follow-on hardening can split provider, wire format, semantic protocol, transport, and response-materialization ownership behind the planning boundary while keeping the public API, fixtures, and scenarios stable.

This also gives fixtures and compatibility tests a stable plan-level object to verify against as lower execution layers harden around the same execution contract.

Replay must still honor the execution surface captured in a fixture even when current planning for that model would choose a newer surface, so old-but-valid fixtures continue to exercise the behavior they were recorded against.

The contributor workflow can expose starter-model verification as a named command because the deterministic planning bridge keeps those slice tests anchored to explicit execution surfaces instead of implicit legacy resolver behavior.
