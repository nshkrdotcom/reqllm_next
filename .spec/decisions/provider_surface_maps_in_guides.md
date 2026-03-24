---
id: reqllm.decision.provider_surface_maps_in_guides
status: accepted
date: 2026-03-23
affects:
  - reqllm.workflow
  - reqllm.model_compat
---

# Provider Surface Maps Live In Guides

## Context

ReqLlmNext is using Beadwork, Spec Led Development, fixture-backed compat runs, and curated support matrices to grow provider coverage deliberately.

When a provider surface gets broad, contributors need one place to see:

1. the official provider surface area
2. the current ReqLlmNext support boundary
3. the partial and missing areas
4. which runtime layer should own each gap

That information is too broad and too time-sensitive for the README, but it is still important enough to publish and keep near the spec workspace.

## Decision

ReqLlmNext will keep provider-wide surface maps in `guides/` and publish them through HexDocs.

These guides may summarize:

1. official provider documentation
2. current support status
3. curated support-matrix strategy
4. architectural ownership of provider-specific gaps

They are supporting guides, not current-truth subject specs.

The `.spec/specs/` workspace remains the canonical contract layer. Subject specs may reference provider surface guides as supporting context, but the guides do not replace requirements, verification links, or ADRs.

## Consequences

Provider expansion work can start from a durable, shareable map instead of reconstructing the provider surface from issue history every time.

Compat and workflow subjects can point at the guide layer without forcing the README or a single subject spec to absorb the whole provider matrix.

Provider research becomes easier to publish, update, and review while the stricter contract layer stays compact.
