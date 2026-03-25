---
id: reqllm.decision.canonical_output_items
status: accepted
date: 2026-03-25
affects:
  - reqllm.architecture
  - reqllm.package
  - reqllm.execution_plan
---

# Normalize Responses Through Canonical Output Items

## Context

ReqLlmNext originally normalized buffered and streamed responses primarily as one assistant message plus metadata. That was sufficient for basic text, tool calls, and usage, but it became increasingly lossy as the package grew to cover thinking or reasoning content, audio and transcript fragments, provider-native items, richer tool lifecycles, and future realtime or media outputs.

## Decision

ReqLlmNext now normalizes runtime output through canonical output items first, then derives higher-level convenience shapes such as `Response.message`, `Response.text/1`, `Response.thinking/1`, `StreamResponse.text/1`, and media helpers from that richer internal model.

The canonical output-item layer is package-owned and cross-provider. It is responsible for preserving meaningful distinctions such as text, thinking, audio, transcript, tool-call, content-part, annotation, refusal, and provider-item channels without forcing those distinctions into provider-specific metadata blobs.

`provider_meta` remains available, but it is now reserved for true provider extras rather than serving as the primary carrier for canonical result semantics.

## Consequences

Shared response materialization can stay consistent across buffered HTTP, streamed HTTP, realtime event reduction, and future richer provider output envelopes.

Providers can contribute richer result channels without forcing the top-level public helpers to become provider-specific.

Future work on realtime, richer media, and server-tool artifacts can build on the same canonical response core instead of inventing parallel normalization paths.
