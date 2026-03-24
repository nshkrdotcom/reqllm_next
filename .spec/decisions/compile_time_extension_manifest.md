---
id: reqllm.decision.compile_time_extension_manifest
status: accepted
date: 2026-03-24
affects:
  - reqllm.extension_manifest
  - reqllm.package
  - reqllm.source_layout
  - reqllm.workflow
---

# Compile-Time Extension Manifest

## Context

ReqLlmNext needs to support a wide and growing model surface without turning provider and model edge cases into imperative branching scattered through shared planner, profile, and execution code.

The package also needs to preserve a strong default path for OpenAI-compatible providers so that common integrations can reuse a shared family without large amounts of new code.

## Decision

ReqLlmNext will move toward a compile-time extension manifest built from declarative family and rule data.

The runtime contract is plain data:

1. extension families define default execution behavior
2. extension rules define narrow opt-in overrides
3. explicit seam patches define what can change
4. precedence is deterministic

Spark may be used as an authoring DSL for these declarations, but runtime code must consume the resulting plain manifest data rather than depending directly on Spark internals.

## Consequences

Positive:
1. keeps the happy path simple and reusable
2. makes OpenAI-compatible providers cheaper to support
3. gives contributors a bounded way to express edge cases
4. enables compile-time validation of overlap, bad references, and missing fallbacks

Tradeoffs:
1. introduces a new declaration and manifest layer that must stay well designed
2. requires migration away from existing imperative provider branching
3. demands careful seam design so the DSL stays narrow and useful rather than becoming another escape hatch
