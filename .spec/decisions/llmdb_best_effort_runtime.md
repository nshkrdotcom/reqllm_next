---
id: reqllm.decision.llmdb_best_effort_runtime
status: accepted
date: 2026-03-26
affects:
  - reqllm.architecture
  - reqllm.enforcement
  - reqllm.execution_plan
  - reqllm.execution_surfaces
  - reqllm.model_profile
  - reqllm.package
  - reqllm.public_api
  - reqllm.source_layout
---

# Typed LLMDB Metadata Drives Best-Effort Runtime

## Context

ReqLlmNext already had a strong first-class provider story through compile-time
extension packs, co-located provider slices, and deterministic execution-plan
resolution.

That architecture still left one gap in the package promise: many packaged
`LLMDB` providers and models were visible to callers as catalog inputs, but they
could not execute unless ReqLlmNext also had an explicit provider registration
and provider-owned slice.

`LLMDB` now exposes typed runtime metadata on `Provider.runtime` and typed
operation execution metadata on `Model.execution`. That upstream contract makes
it possible to distinguish three cases explicitly:

1. first-class integrated providers with dedicated provider slices
2. best-effort packaged providers whose runtime metadata is complete enough to
   execute safely through an existing canonical family
3. unsupported or catalog-only models that should fail fast with an actionable
   reason instead of falling through provider-name heuristics

## Decision

ReqLlmNext now treats typed `LLMDB` runtime metadata as the upstream source of
truth for generic best-effort execution.

The package keeps first-class provider and family slices as the authoritative
path when they exist, including deeper validation, richer provider utilities,
and provider-specific normalization.

When no first-class provider registration exists, ReqLlmNext may execute a model
through a generic provider path only when all of the following are true:

1. `LLMDB.Provider.runtime` is present and complete enough to build auth and
   endpoint roots
2. `LLMDB.Model.execution` declares a supported operation entry
3. that execution entry names a known canonical family that ReqLlmNext already
   knows how to execute

When the generic provider path is active, the provider layer shall consume the
typed runtime contract directly instead of reintroducing provider-name
heuristics. That includes:

1. auth styles such as bearer, x-api-key, query, header, and multi-header
2. templated provider runtime configuration such as account-scoped base URLs
3. operation-specific `base_url`, `path`, and `provider_model_id` overrides
   declared on `LLMDB.Model.execution`

Best-effort generic support is limited to canonical operations:

1. text
2. object
3. embed
4. image
5. transcription
6. speech
7. realtime

Provider-native utility endpoints are not implied by best-effort support and
remain provider-scoped.

ReqLlmNext also exposes explicit support introspection through
`ReqLlmNext.support_status/1`, which returns:

1. `:first_class`
2. `:best_effort`
3. `{:unsupported, reason}`

Unsupported reasons shall be explicit for catalog-only models, missing runtime
metadata, missing execution metadata, and unknown execution families.

## Consequences

Benefits:

1. the package can honestly accept all `LLMDB` models as input
2. executable packaged models no longer require bespoke provider registration in
   every case
3. provider-name heuristics lose authority in favor of typed upstream execution
   metadata
4. first-class providers still keep deeper proof and provider-native utility
   coverage where they add real value

Tradeoffs:

1. ReqLlmNext now depends more directly on the quality of upstream `LLMDB`
   runtime metadata
2. the package must keep an explicit mapping from upstream execution-family ids
   to local runtime families
3. support claims now need to distinguish first-class and best-effort execution
   tiers rather than flattening everything into one support word
