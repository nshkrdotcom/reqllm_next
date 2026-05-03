---
id: reqllm.decision.governed_authority_boundary
status: accepted
date: 2026-05-03
affects:
  - reqllm.architecture
  - reqllm.provider
  - reqllm.package
  - reqllm.layer_boundaries
  - reqllm.source_layout
---

# Governed Authority Boundary

## Context

ReqLlmNext supports standalone local development where provider modules can read local environment variables and callers can pass direct API keys or endpoint roots. That behavior is useful for replay, live verifier, and package-development ergonomics, but it is not sufficient for externally governed execution.

Governed callers need one explicit authority contract that carries credential, lease, route, query, account, project, realtime-session, policy, and redaction references without falling back to machine environment state or ad hoc request options.

## Decision

ReqLlmNext adds `ReqLlmNext.GovernedAuthority` as the governed-mode authority contract.

When `:governed_authority` is present:

1. provider request construction uses the authority base URL, headers, query, and template values
2. direct API keys, direct base URLs, absolute endpoint URLs, auth tuples, header options, realtime tokens, organization ids, project ids, account ids, provider-account ids, and model-account ids are rejected as unmanaged authority
3. typed runtime metadata may still provide non-secret default routes, headers, and query defaults, but env-backed runtime credentials are not used
4. canonical HTTP, streaming, media, embedding, OpenAI realtime, OpenAI Responses WebSocket, and provider-owned utility paths share the same provider-layer authority checks
5. fixture capture and replay redact governed credential headers with the same standards used for standalone provider credentials

Standalone env behavior remains available only when governed authority is absent.

## Consequences

Positive:

1. governance-sensitive deployments get one inspectable authority handoff instead of implicit process env state
2. provider-owned utility endpoints cannot bypass the governed credential path
3. best-effort runtime metadata can keep typed route defaults without reintroducing env credential fallback in governed mode

Tradeoffs:

1. provider and wire modules must avoid injecting direct `:base_url` request options when governed authority is present
2. tests need explicit governed lanes for shared provider, utility, realtime, media, and embedding paths
3. local `.env` ergonomics must be documented as standalone-only behavior
