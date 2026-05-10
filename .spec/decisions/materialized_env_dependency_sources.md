---
id: reqllm.decision.materialized_env_dependency_sources
status: accepted
date: 2026-05-10
affects:
  - reqllm.architecture
  - reqllm.diagnostics
  - reqllm.enforcement
  - reqllm.execution_plan
  - reqllm.execution_surfaces
  - reqllm.layer_boundaries
  - reqllm.model_compat
  - reqllm.model_input
  - reqllm.model_profile
  - reqllm.operation_planner
  - reqllm.package
  - reqllm.provider
  - reqllm.public_api
  - reqllm.source_layout
  - reqllm.telemetry
  - reqllm.workflow
---

# Materialized Env And Dependency Sources

## Context

ReqLlmNext historically allowed runtime provider code, fixture helpers, and
compat tasks to read or mutate process environment directly. It also selected
local ExecutionPlane package dependencies through bespoke `mix.exs` path logic.

That made local development convenient, but it spread deployment configuration
and dependency-selection policy across runtime modules and Mix helpers.

## Decision

Runtime package code reads credentials, fixture mode, provider base URL
overrides, and runtime metadata credential fallbacks through `ReqLlmNext.Env`,
the package-owned materialized application env boundary. Deployment env is
materialized by config, and local `.env` loading updates application env without
overriding values already supplied by runtime config or the caller.

Dependency source selection for ExecutionPlane package dependencies is owned by
checked-in `build_support/dependency_sources.exs` and
`build_support/dependency_sources.config.exs`. Local path, GitHub subdir, and
Hex fallback behavior must be explicit in that manifest and must not depend on
environment variables or one-off `mix.exs` resolver logic.

Governed execution remains stricter than standalone execution: governed callers
must supply authority through `ReqLlmNext.GovernedAuthority`, and env fallback
is not a governed credential or route authority.

## Consequences

Runtime modules no longer need direct OS env APIs.

Tests and compat tasks that need env-shaped behavior can mutate
`ReqLlmNext.Env` directly without leaking local shell secrets into deterministic
suite runs.

Clean clones can resolve internal package dependencies through the same
manifest shape used for local development and future publish checks.
