---
id: reqllm.decision.media_operation_families
status: accepted
date: 2026-03-24
affects:
  - reqllm.public_api
  - reqllm.package
  - reqllm.architecture
---

# Media Operation Families

## Context

`ReqLLM` already established a public frontend media API with `generate_image`, `transcribe`, and `speak`.

`ReqLlmNext` needs to preserve that public package boundary without regressing into the old imperative provider-operation branching model.

## Decision

`ReqLlmNext` keeps the same top-level media API shape as `ReqLLM`, but media operations are modeled as first-class planner operations rather than special helper branches.

`generate_image` returns the canonical `ReqLlmNext.Response` shape because generated image output fits the package's content-part response model.

`transcribe` and `speak` return dedicated Zoi-backed result contracts because they are not text-generation responses and should not be forced into the `Response` shape.

Providers that do not implement a standalone media operation shall fail through the same structured capability path used by other unsupported operations.

## Consequences

The public API can preserve frontend parity while keeping media implementation aligned with the v2 execution-plan architecture.

OpenAI media lanes can be added as provider-owned surfaces.

Anthropic can continue supporting multimodal input on text/object lanes while explicitly rejecting standalone media operations until such surfaces exist.
