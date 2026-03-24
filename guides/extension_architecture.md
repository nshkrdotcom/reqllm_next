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
- `ReqLlmNext.Extensions.Compiled` for the aggregated built-in manifest

That keeps the runtime dependent on plain data while still giving contributors a
more structured authoring surface.

## Families

A family defines the default execution behavior for a class of models.

Examples:

- `:openai_chat_compatible`
- `:openai_responses_compatible`
- `:anthropic_messages`

Families are selected by declarative criteria and ordered by:

1. higher `priority`
2. higher criteria specificity
3. declaration order

If no family-specific override exists, the selected family is the happy path.

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

## Fallback Principle

The extension architecture must always preserve fallback behavior.

- If no rule matches, the family default stands.
- If no family-specific provider behavior is declared, the shared runtime still
  has a deterministic path.
- OpenAI-compatible providers should be able to reuse a default family and opt
  in only to their actual differences.

That is the architectural goal the DSL and manifest system are meant to serve.
