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
```

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
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/provider.spec.md
  covers:
    - reqllm.provider.auth_and_roots
    - reqllm.provider.route_ownership
    - reqllm.provider.no_model_behavior
```
