---
id: reqllm.decision.governed_authority_boundary
status: accepted
date: 2026-05-03
affects:
  - reqllm.architecture
  - reqllm.diagnostics
  - reqllm.enforcement
  - reqllm.execution_mode
  - reqllm.execution_plan
  - reqllm.execution_surfaces
  - reqllm.model_compat
  - reqllm.model_input
  - reqllm.model_profile
  - reqllm.operation_planner
  - reqllm.provider
  - reqllm.package
  - reqllm.policy_rules
  - reqllm.session_runtime
  - reqllm.telemetry
  - reqllm.workflow
  - reqllm.layer_boundaries
  - reqllm.source_layout
---

# Governed Authority Boundary

## Context

ReqLlmNext supports standalone local development where provider modules can read local environment variables and callers can pass direct API keys or endpoint roots. That behavior is useful for replay, live verifier, and package-development ergonomics, but it is not sufficient for externally governed execution.

Governed callers need one explicit authority contract that carries credential,
lease, provider-key, base-url, route, query, account, project, endpoint,
realtime-session, realtime-token, reconnect-token, stream, cleanup-policy,
policy, redaction, and revocation references without falling back to machine
environment state or ad hoc request options.

## Decision

ReqLlmNext adds `ReqLlmNext.GovernedAuthority` as the governed-mode authority contract.

When `:governed_authority` is present:

1. provider request construction uses the authority base URL, headers, query, and template values
2. provider-key, base-url, cleanup-policy, credential, lease, target,
   operation-policy, redaction, and optional account/realtime refs are projected
   into the resolved `ExecutionPlan` as refs only
3. direct API keys, direct base URLs, absolute endpoint URLs, auth tuples,
   header options, realtime tokens, organization ids, project ids, account ids,
   provider-account ids, and model-account ids are rejected as unmanaged
   authority
4. realtime websocket URL construction and streaming validate active lease,
   granted target, current revocation state, realtime session ref, realtime
   session token ref, reconnect token ref, and stream ref before provider effect
5. cleanup evidence for realtime materialization removes raw session tokens,
   reconnect tokens, stream auth, and provider headers and records only refs plus
   removed materialized key names
6. telemetry may carry `authority_refs`, but no materialized credential header,
   realtime session token, reconnect token, stream auth, env secret, or direct
   provider option value
7. typed runtime metadata may still provide non-secret default routes, headers,
   and query defaults, but env-backed runtime credentials are not used
8. canonical HTTP, streaming, media, embedding, OpenAI realtime, OpenAI Responses
   WebSocket, and provider-owned utility paths share the same provider-layer
   authority checks
9. fixture capture and replay redact governed credential headers with the same
   standards used for standalone provider credentials

Standalone env behavior remains available only when governed authority is absent.

## Consequences

Positive:

1. governance-sensitive deployments get one inspectable authority handoff instead of implicit process env state
2. provider-owned utility endpoints cannot bypass the governed credential path
3. best-effort runtime metadata can keep typed route defaults without reintroducing env credential fallback in governed mode
4. workflow planners can prove multiple provider keys and multiple providers in
   one run by comparing refs instead of materialized credential values
5. realtime reconnect and cleanup have deterministic local proof without
   requiring live provider credentials

Tradeoffs:

1. provider and wire modules must avoid injecting direct `:base_url` request options when governed authority is present
2. tests need explicit governed lanes for shared provider, utility, realtime, media, and embedding paths
3. local `.env` ergonomics must be documented as standalone-only behavior
4. authority schema changes must update subject specs and focused tests together
   because the plan, realtime, telemetry, provider, and workflow subjects all
   observe the same boundary
