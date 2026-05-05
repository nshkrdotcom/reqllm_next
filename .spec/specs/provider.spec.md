# Provider

Current-truth provider-boundary contract for ReqLlmNext 2.0.

<!-- covers: reqllm.provider.auth_and_roots reqllm.provider.route_ownership reqllm.provider.no_model_behavior -->

```spec-meta
id: reqllm.provider
kind: provider
status: active
summary: Auth strategy, endpoint roots, and provider headers separated from request semantics.
surface:
  - .spec/specs/provider.spec.md
  - .spec/specs/layer_boundaries.spec.md
decisions:
  - reqllm.decision.execution_layers
  - reqllm.decision.provider_specific_endpoint_utilities
  - reqllm.decision.governed_authority_boundary
```

## Phase 10 Governed Authority Update

Governed provider authority now includes explicit provider-key and base-url refs
plus cleanup policy, endpoint account, realtime session token, reconnect token,
stream, and revocation refs. Provider code may use materialized headers and
base URLs only from the selected authority and must reject unmanaged direct
provider keys, raw realtime token options, direct headers, direct URLs, and env
credential fallback in governed mode.

## Requirements

```spec-requirements
- id: reqllm.provider.auth_and_roots
  statement: Provider shall own provider identity, API-key lookup, auth strategy, provider headers, and endpoint roots by transport family.
  priority: must
  stability: evolving

- id: reqllm.provider.route_ownership
  statement: Provider shall own endpoint roots only, while wire format owns relative routes and event targets so URL ownership remains unambiguous.
  priority: must
  stability: evolving

- id: reqllm.provider.no_model_behavior
  statement: Provider shall not choose model-specific behavior, encode request payloads, decode provider events, or manage continuation state.
  priority: must
  stability: evolving

- id: reqllm.provider.utility_roots
  statement: Provider-specific utility endpoints may reuse provider auth and root configuration, but those endpoints shall remain outside the canonical cross-provider facade and outside wire or semantic-protocol ownership.
  priority: should
  stability: evolving

- id: reqllm.provider.governed_authority
  statement: In governed mode, provider auth and route roots shall come only from `ReqLlmNext.GovernedAuthority`; direct provider keys, direct base URLs, direct URLs, headers, realtime tokens, organization or project identifiers, account or model-account identifiers, and runtime-metadata env credential fallbacks shall be rejected as unmanaged authority while HTTP, streaming, media, embedding, OpenAI realtime, OpenAI Responses WebSocket, runtime metadata, and provider-owned utility request paths reuse governed base URL, headers, query, and template values.
  priority: must
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/provider.spec.md
  covers:
    - reqllm.provider.auth_and_roots
    - reqllm.provider.route_ownership
    - reqllm.provider.no_model_behavior
    - reqllm.provider.utility_roots
    - reqllm.provider.governed_authority

- kind: command
  target: mix test test/req_llm_next/governed_authority_test.exs test/providers/openai/client_test.exs test/providers/anthropic/client_test.exs test/providers/google/wire_embeddings_test.exs test/providers/google/wire_images_test.exs
  execute: true
  covers:
    - reqllm.provider.auth_and_roots
    - reqllm.provider.route_ownership
    - reqllm.provider.utility_roots
    - reqllm.provider.governed_authority
```
