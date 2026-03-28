---
id: reqllm.decision.loaded_optional_wire_callbacks
status: accepted
date: 2026-03-28
affects:
  - reqllm.package
  - reqllm.source_layout
---

# Optional Wire Callbacks Must Load Before Dispatch

## Context

ReqLlmNext keeps provider-family request shaping in wire modules, including
optional callbacks such as custom request builders and wire-specific headers.

That keeps provider-specific request behavior in the owning provider or family
slice instead of pushing versioned headers, dynamic request paths, or other wire
quirks up into shared planner, transport, or provider code.

The shared streaming request builder had been using `function_exported?/3`
directly to detect optional wire callbacks. That is not sufficient when the
module has not been loaded yet, because the callback check can return `false`
even though the provider-owned callback exists.

In practice, that caused the shared path to silently skip provider-owned wire
behavior and fall back to generic request construction. Anthropic requests then
lost required version headers, and Google requests could skip their provider
owned custom request builder.

## Decision

Shared runtime dispatch sites that rely on optional provider-owned or
family-owned callbacks shall ensure the target module is loaded before checking
for callback availability.

For wire dispatch, that means the shared request builder must call
`Code.ensure_loaded?/1` before deciding whether a wire module implements
optional callbacks such as:

1. `build_request/4`
2. `headers/1`

This preserves the source-layout contract:

1. provider-specific request builders remain in provider-owned wire modules
2. provider-specific header logic remains in provider-owned wire modules
3. shared transport and wire helpers may dispatch those callbacks, but they do
   not re-own the provider logic themselves

## Consequences

Benefits:

1. provider-specific request behavior no longer depends on incidental module
   load order
2. Anthropic and Google style wire quirks stay in their owning modules
3. shared fallback logic becomes predictable instead of silently erasing
   provider-specific behavior

Tradeoffs:

1. shared runtime helpers must be slightly more deliberate when probing optional
   callbacks
2. regression tests need to cover unloaded-module callback dispatch explicitly,
   not just loaded happy paths
