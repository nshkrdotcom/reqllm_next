# ReqLlmNext Specs

This folder defines the architecture contracts for ReqLlmNext v2.

## Documents

- `project_summary.md` - High-level summary of the project direction and current architecture thinking.
- `architecture.md` - Overall architecture and how the concern specs fit together.
- `model_compat.md` - Live model compatibility and pressure-test contract.
- `diagnostics.md` - Structured diagnostics and anomaly attribution contract.
- `telemetry.md` - Request lifecycle, reasoning lifecycle, usage, and payload-capture contract.
- `layer_boundaries.md` - Cross-layer handoff and ownership contract.
- `source_layout.md` - Source ownership rules for model quirks and edge cases.
- `enforcement.md` - Boundary enforcement, runtime hard-fail rules, and CI guardrails.
- `model_source.md` - Public model-spec input boundary.
- `model_profile.md` - Descriptive model facts and execution-surface catalog.
- `execution_mode.md` - Normalized request mode contract.
- `execution_surface.md` - Endpoint-style support unit contract.
- `overrides.md` - Policy-rule resolution and layer-scoped adapter contract.
- `execution_plan.md` - Fully resolved execution-plan contract.
- `operation_planner.md` - Planner boundary that turns profile, mode, and rules into a plan.
- `semantic_protocol.md` - Provider API family semantics and canonical event mapping.
- `wire_format.md` - Transport-facing request envelopes and inbound frame decoding contract.
- `transport.md` - HTTP, SSE, and WebSocket transport contract.
- `session_runtime.md` - Persistent session and continuation-state contract.
- `provider.md` - Provider auth, endpoint-root, and key-lookup contract.

## Status

These specs are normative for future refactors unless a newer spec supersedes them.

For the higher-level package narrative that ties these specs to the test, fixture, compat, and agent workflow, see [`guides/package_thesis.md`](/Users/mhostetler/Source/ReqLLM/reqllm_next/guides/package_thesis.md).
