---
id: reqllm.decision.execution_plan_bridge
status: accepted
date: 2026-03-23
affects:
  - reqllm.architecture
  - reqllm.package
---

# Introduce a Deterministic Planning Bridge Before Rewriting Execution Layers

## Context

ReqLlmNext already had working provider, fixture, and scenario machinery, but the spike execution path still selected provider and wire behavior directly from the raw `%LLMDB.Model{}` during execution.

That made it difficult to move the implementation toward the documented v2 architecture without first rewriting every downstream module in one pass.

## Decision

ReqLlmNext introduces a deterministic planning bridge now, before the full execution-layer split is complete.

The runtime must:

1. build `ModelProfile` from resolved model facts
2. normalize request intent into `ExecutionMode`
3. select explicit `ExecutionSurface` support through policy
4. materialize an `ExecutionPlan`
5. drive the existing provider and wire modules from that plan

The existing provider and wire modules remain transitional execution backends during this stage. They are no longer allowed to choose request behavior independently.

## Consequences

The planner becomes the single place where request behavior is selected, which lets starter model slices be implemented against the new architecture without waiting for a full transport and protocol refactor.

Future refactors can split provider, wire format, semantic protocol, and transport behind the planning boundary while keeping the public API, fixtures, and scenarios stable.

This also gives fixtures and compatibility tests a stable plan-level object to verify against as the lower execution layers continue to evolve.
