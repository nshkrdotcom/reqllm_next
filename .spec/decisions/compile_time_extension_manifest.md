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

The contributor-facing authoring surface should be shaped around intent:

1. `register` for provider-owned seams
2. `match` for family and rule criteria
3. `stack` for family-owned runtime seams
4. `patch` for rule-owned override seams
5. `extends` so child families can reuse a happy-path family and declare only their differences

The package therefore has three distinct pieces:

1. plain runtime structs such as `Provider`, `Family`, `Rule`, and `Manifest`
2. Spark authoring modules such as `ReqLlmNext.Extensions.Dsl` and `ReqLlmNext.Extensions.Definition`
3. compiled built-in manifest modules such as `ReqLlmNext.Extensions.Compiled`

Built-in declarations should live in small provider or family definition packs under `lib/req_llm_next/families/**/definition.ex` and `lib/req_llm_next/providers/**/definition.ex` rather than one monolithic built-ins file or a hand-maintained central registration list so OpenAI-compatible defaults, provider-specific families, and narrow model or mode overrides stay obvious to contributors.

Automatic discovery of built-in declarations may parse provider and family
definition source files, but it must resolve only declared existing modules and
must not create module atoms from provider, fixture, generated, persisted,
operator, or other runtime input.

Family resolution must prefer declarative criteria matches first, then provider-registered default families, and finally explicit global default families.

Shared profile construction must consume provider-facts and surface-catalog seams from the compiled manifest rather than branching on provider atoms in generic code.

Compile-time verification must reject duplicate ids, missing default-family references, missing global defaults, illegal seam ownership, and missing seam modules before the compiled manifest becomes runtime truth.

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
4. requires inheritance semantics that are easy to reason about when a family reuses a parent stack

Guardrails:
1. Spark declarations may not become the runtime extension API
2. built-in declarations must still compile down to plain manifest data before execution, even when discovered automatically from definition-pack files
3. contributor-facing extension work should prefer declared families and rules over edits to shared planner or executor branching
4. module discovery must stay deterministic, source-owned, and fail closed when a declared module cannot be resolved
