# ReqLlmNext Specs

This folder defines the architecture contracts for ReqLlmNext v2.

## Documents

- `project_summary.md` - High-level summary of the project direction and current architecture thinking.
- `architecture.md` - Overall architecture and how the concern specs fit together.
- `enforcement.md` - Boundary enforcement, runtime hard-fail rules, and CI guardrails.
- `model_source.md` - Public model-spec input forms and local-model normalization.
- `model_profile.md` - Resolved model profile contract.
- `operation_planner.md` - Request planning and execution-plan contract.
- `semantic_protocol.md` - Provider API family semantics and canonical event mapping.
- `transport.md` - HTTP, SSE, and WebSocket transport contract.
- `session_runtime.md` - Persistent session and continuation-state contract.
- `provider.md` - Provider auth, endpoint-root, and key-lookup contract.
- `overrides.md` - Provider/model overrides and adapter rules.

## Status

These specs are normative for future refactors unless a newer spec supersedes them.
