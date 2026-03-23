---
id: reqllm.decision.self_contained_fixture_inputs
status: accepted
date: 2026-03-23
affects:
  - reqllm.architecture
  - reqllm.package
  - reqllm.model_compat
  - reqllm.diagnostics
  - reqllm.workflow
---

# Fixture and Compat Inputs Must Be Self-Contained

## Context

ReqLlmNext depends on live fixture recording and replay to verify that heterogeneous provider APIs still normalize into one canonical API surface.

That verification becomes noisy when a scenario depends on third-party assets that providers must fetch on the open internet. A live failure caused by an upstream image host, CDN throttling, or transient HTTP policy does not tell us whether ReqLlmNext normalized the provider correctly.

This became concrete in the image-input scenario, where an external image URL caused OpenAI live coverage to fail because the upstream asset host returned `429`.

## Decision

ReqLlmNext treats fixture and compatibility inputs as part of the verification contract.

When a scenario needs non-text input:

1. prefer repo-owned or otherwise self-contained inputs over third-party hotlinks
2. support binary content parts as first-class canonical input so scenario code does not need provider-specific URL hacks
3. let wire modules translate canonical binary input into the provider-specific payload shape required for execution

External URLs may still be supported as user input, but they are not the preferred basis for compatibility scenarios or fixture recording when a self-contained asset can express the same behavior.

## Consequences

Live compatibility failures stay focused on provider behavior and ReqLlmNext normalization rather than upstream asset availability.

Fixture replay remains deterministic because the recorded prompt shape and captured provider traffic are anchored to stable local inputs.

The canonical API surface becomes stronger because binary media is exercised through the same model-agnostic path as text and tool inputs.
