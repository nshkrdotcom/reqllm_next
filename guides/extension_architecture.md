# Extension Architecture

ReqLlmNext is moving from imperative provider branching toward a compile-time
extension manifest.

The goal is to keep the happy path simple:

1. `LLMDB` resolves a safe provider atom and model metadata
2. ReqLlmNext resolves a default execution family
3. narrow override rules opt in to provider, model, or mode edge cases
4. the runtime consumes the compiled manifest rather than branching through
   central shared modules

## Why

The package needs to support a wide range of models without turning every
contributor edge case into new planner or executor branching.

That means the extension story has to be:

- declarative
- compile-time checked
- deterministic
- narrow in scope
- compatible with a default OpenAI-style happy path

## Core Runtime Contract

The runtime contract is plain Elixir data, independent of any DSL authoring
layer:

- `ReqLlmNext.Extensions.Criteria`
- `ReqLlmNext.Extensions.Seams`
- `ReqLlmNext.Extensions.Family`
- `ReqLlmNext.Extensions.Rule`
- `ReqLlmNext.Extensions.Manifest`

Spark may be used to author declarations, but the runtime should only consume
the resulting family and rule data.

The current built-in authoring stack is:

- `ReqLlmNext.Extensions.Dsl` for Spark sections and entities
- `ReqLlmNext.Extensions.Definition` for extension-definition modules
- provider and family declaration packs discovered from `lib/req_llm_next/families/**/definition.ex` and `lib/req_llm_next/providers/**/definition.ex`
- `ReqLlmNext.Extensions.Compiled` for the aggregated built-in manifest
- `ReqLlmNext.Extensions.ManifestVerifier` for compile-time merged-manifest checks

That keeps the runtime dependent on plain data while still giving contributors a
more structured authoring surface.

The intended contributor shape is:

1. reuse an existing default family when possible
2. add a small provider or family definition pack when needed
3. add narrow rules for real edge cases
4. let compile-time manifest verification catch duplicates, bad references, and illegal seam ownership

The DSL surface is intentionally shaped around author intent:

- `register` for provider-owned seams
- `match` for family and rule criteria
- `stack` for family-owned runtime seams
- `patch` for rule-owned overrides
- `extends` for reusing an existing family and only declaring the differences

That keeps the contributor story closer to "start from the happy path, then opt
into only the edge-case deltas" than "restate the whole runtime stack for every
provider family".

## Families

A family defines the default execution behavior for a class of models.

Examples:

- `:openai_chat_compatible`
- `:openai_responses_compatible`
- `:anthropic_messages`
- `:deepseek_chat_compatible`

Families are selected by declarative criteria and ordered by:

1. higher `priority`
2. higher criteria specificity
3. declaration order

If no criteria-selected family matches, family resolution falls back through:

1. the provider's registered default family
2. the highest-priority global default family

## Rules

Rules are opt-in exceptions layered on top of the selected family.

Rules apply only when their criteria match the runtime context. Matching rules
are applied in ascending order so more specific or higher-priority patches win
later.

This keeps edge cases narrow and explicit.

## Allowed Override Seams

Extensions may patch only explicit seams:

- provider module registration
- provider-facts extraction
- surface catalog construction
- surface preparation
- session runtime module mapping
- semantic protocol module mapping
- wire module mapping
- transport module mapping
- adapter module registration
- provider-native utility module registration

Extensions should not rewrite the public API or the canonical response model
directly.

## Matching Context

Criteria may match on:

- provider atom
- selected family
- exact model id
- operation
- transport
- semantic protocol
- mode flags such as `stream?`, `tools?`, and `structured?`
- normalized facts
- normalized features

This supports a default path with narrowly scoped exceptions.

One current proof point is DeepSeek: it reuses the OpenAI-compatible chat family
shape, then narrows only the provider-owned differences such as provider
registration, reasoning-content semantic decoding, and request-body thinking
controls. That is the exact contribution shape the extension system is supposed
to enable.

## Fallback Principle

The extension architecture must always preserve fallback behavior.

- If no rule matches, the family default stands.
- If no family-specific provider behavior is declared, the shared runtime still
  has a deterministic path.
- OpenAI-compatible providers should be able to reuse a default family and opt
  in only to their actual differences.

The compiled runtime registry acts as the shared fallback table for globally
addressable seam keys, while resolved provider or family seams may still shadow
those keys locally for one selected execution stack.

That is the architectural goal the DSL and manifest system are meant to serve.
