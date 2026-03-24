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

Spark is the accepted authoring layer for built-in extension declarations, but runtime code must consume the resulting plain manifest data rather than depending directly on Spark internals.

The package therefore has three distinct pieces:

1. plain runtime structs such as `Provider`, `Family`, `Rule`, and `Manifest`
2. Spark authoring modules such as `ReqLlmNext.Extensions.Dsl` and `ReqLlmNext.Extensions.Definition`
3. compiled built-in manifest modules such as `ReqLlmNext.Extensions.Compiled`

Family resolution must prefer declarative criteria matches first, then provider-registered default families, and finally explicit global default families.

Shared profile construction must consume provider-facts and surface-catalog seams from the compiled manifest rather than branching on provider atoms in generic code.

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

Guardrails:
1. Spark declarations may not become the runtime extension API
2. built-in declarations must still compile down to plain manifest data before execution
3. contributor-facing extension work should prefer declared families and rules over edits to shared planner or executor branching
