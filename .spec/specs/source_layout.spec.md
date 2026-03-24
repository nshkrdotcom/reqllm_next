# Source Layout

Current-truth source-ownership contract for ReqLlmNext.

<!-- covers: reqllm.source_layout.concern_homes reqllm.source_layout.public_contract_home reqllm.source_layout.layer_scoped_quirks reqllm.source_layout.compat_outside_runtime -->

```spec-meta
id: reqllm.source_layout
kind: source_layout
status: active
summary: Source ownership rules that keep the top-level facade, planning logic, semantic protocol logic, provider-specific utilities, and compat tooling in distinct homes.
surface:
  - AGENTS.md
  - .spec/specs/source_layout.spec.md
  - lib/req_llm_next/**/*.ex
  - lib/req_llm_next/anthropic/**/*.ex
  - test/support/**/*.ex
  - test/**/*.exs
```

## Requirements

```spec-requirements
- id: reqllm.source_layout.concern_homes
  statement: ReqLlmNext shall keep model-boundary concerns, provider-scoped fact extraction, manifest-backed provider registration, profile construction, mode normalization, policy resolution, surface-owned request preparation, semantic protocol normalization, wire envelopes, transport mechanics, response materialization, fixture replay, and session state in distinct source locations that match the architecture.
  priority: must
  stability: evolving

- id: reqllm.source_layout.public_contract_home
  statement: Top-level package-boundary tests for `ReqLlmNext` shall live in a dedicated `test/public_api/` home so the canonical facade contract remains distinct from executor, protocol, wire, transport, and scenario tests.
  priority: must
  stability: evolving

- id: reqllm.source_layout.layer_scoped_quirks
  statement: Imperative quirks shall live in explicit layer-scoped adapters rather than in omniscient global hooks or ad hoc model-name branches spread across the stack.
  priority: must
  stability: evolving

- id: reqllm.source_layout.compat_outside_runtime
  statement: Compat-only expectations, issue drafting, and drift analysis shall live in compat tooling rather than inside provider, planner, protocol, wire, transport, or session runtime modules.
  priority: must
  stability: evolving

- id: reqllm.source_layout.provider_utilities
  statement: Provider-specific non-canonical endpoints shall live in explicit provider-scoped utility modules rather than expanding the top-level package facade or collapsing utility flows into provider, wire, or transport modules.
  priority: should
  stability: evolving

- id: reqllm.source_layout.extension_contract_home
  statement: Compile-time execution extension contracts shall live in a dedicated `lib/req_llm_next/extensions/` home, including the plain runtime structs, Spark DSL authoring modules, compiled manifest modules, and built-in declarations, so default execution families and edge-case override rules are defined outside the shared planner and executor code.
  priority: should
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: .spec/specs/source_layout.spec.md
  covers:
    - reqllm.source_layout.concern_homes
    - reqllm.source_layout.public_contract_home
    - reqllm.source_layout.layer_scoped_quirks
    - reqllm.source_layout.compat_outside_runtime
    - reqllm.source_layout.provider_utilities
    - reqllm.source_layout.extension_contract_home
```
