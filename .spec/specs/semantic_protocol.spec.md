# Semantic Protocol

Current-truth semantic API-family contract for ReqLlmNext 2.0.

<!-- covers: reqllm.semantic_protocol.family_meaning reqllm.semantic_protocol.transport_separation reqllm.semantic_protocol.canonical_chunks -->

```spec-meta
id: reqllm.semantic_protocol
kind: semantic_protocol
status: active
summary: Provider API-family meaning, payload mapping, and canonical chunk decoding, including rich provider-native metadata preservation.
surface:
  - .spec/specs/semantic_protocol.spec.md
  - .spec/specs/layer_boundaries.spec.md
  - lib/req_llm_next/semantic_protocols/anthropic_messages.ex
decisions:
  - reqllm.decision.execution_layers
```

## Requirements

```spec-requirements
- id: reqllm.semantic_protocol.family_meaning
  statement: Semantic protocol shall own the meaning of a provider API family by mapping `ExecutionPlan` into protocol payloads and decoding provider-family events back into canonical chunks.
  priority: must
  stability: evolving

- id: reqllm.semantic_protocol.transport_separation
  statement: Semantic protocol shall remain separate from wire format, transport, and provider concerns and shall not choose sockets, retries, auth headers, or transport routes.
  priority: must
  stability: evolving

- id: reqllm.semantic_protocol.canonical_chunks
  statement: Semantic protocol shall normalize family-specific events into the canonical ReqLlmNext chunk and terminal-metadata shapes used by the rest of the runtime and compat tooling.
  priority: must
  stability: evolving

- id: reqllm.semantic_protocol.provider_rich_events
  statement: Semantic protocol shall preserve rich provider-family semantics such as Anthropic citations, stop reasons, response identifiers, and server-tool result blocks by mapping them into canonical content or metadata rather than dropping them silently at the wire boundary.
  priority: should
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/semantic_protocol.spec.md
  covers:
    - reqllm.semantic_protocol.family_meaning
    - reqllm.semantic_protocol.transport_separation
    - reqllm.semantic_protocol.canonical_chunks
    - reqllm.semantic_protocol.provider_rich_events

- kind: command
  target: mix test test/semantic_protocols/anthropic_messages_test.exs
  execute: true
  covers:
    - reqllm.semantic_protocol.provider_rich_events
```
