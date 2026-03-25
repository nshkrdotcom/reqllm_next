# Contributor Workflow

Repository workflow contract for Beadwork and Spec Led Development.

<!-- covers: reqllm.workflow.beadwork_primed reqllm.workflow.specled_loop reqllm.workflow.agent_instructions reqllm.workflow.starter_slice_verification -->

```spec-meta
id: reqllm.workflow
kind: workflow
status: active
summary: Contributor workflow contract for durable work tracking, current-truth maintenance, and keeping contributor docs aligned with the Spec Led workspace, including the public model-input boundary contract, the thin facade guidance in AGENTS, and the repo's package-thesis narrative.
surface:
  - README.md
  - AGENTS.md
  - .spec/README.md
  - .spec/AGENTS.md
  - guides/extension_architecture.md
  - guides/package_thesis.md
  - guides/anthropic_surface_map.md
  - guides/openai_surface_map.md
  - guides/anthropic_openai_compatibility.md
  - mix.exs
decisions:
  - reqllm.decision.zoi_backed_struct_contracts
```

## Requirements

```spec-requirements
- id: reqllm.workflow.beadwork_primed
  statement: Contributor and agent workflows shall start by loading Beadwork context so durable work state survives session boundaries.
  priority: must
  stability: evolving

- id: reqllm.workflow.specled_loop
  statement: Contributor workflow shall keep `.spec/` as the canonical spec workspace and use `mix spec.prime`, `mix spec.next`, and `mix spec.check` to maintain the subject specs, ADRs, README, AGENTS, and package-thesis guide in sync with current truth, including top-level media API parity, request-fixture replay behavior, runtime telemetry, canonical output items, and transport-agnostic realtime behavior when those package boundaries evolve.
  priority: must
  stability: evolving

- id: reqllm.workflow.agent_instructions
  statement: Repository agent instructions shall direct agents to run bw prime before work and mix spec.prime --base HEAD before editing current-truth package guidance, and they shall keep provider-native behavior behind planning, layer, and provider-utility boundaries instead of reintroducing shared executor shortcuts while standardizing package-owned structs on Zoi-backed schemas instead of plain `defstruct` declarations, emitting package-level runtime telemetry through `ReqLlmNext.Telemetry`, and preserving the top-level ReqLLM-style text, object, media, and embedding facade.
  priority: must
  stability: evolving

- id: reqllm.workflow.starter_slice_verification
  statement: Contributor workflow shall provide named verification entry points for the current starter-model slices and curated provider support-matrix lanes so replay-backed checks, live fixture refreshes, websocket coverage, and provider-feature probes use explicit shared paths.
  priority: should
  stability: evolving

- id: reqllm.workflow.provider_surface_guides
  statement: Provider expansion work shall keep provider surface-map and compatibility-evaluation guides in sync with code and subject specs so wide provider coverage remains explainable and reviewable.
  priority: should
  stability: evolving

- id: reqllm.workflow.extension_dsl_guidance
  statement: Contributor workflow shall keep the extension-architecture guide, Spark dependency, compile-time manifest proof, definition-pack layout, discovery of built-in definitions from co-located family and provider slice homes, match or stack or patch authoring surface, inheritance behavior, manifest-backed provider fallback and verification behavior, and at least one concrete OpenAI-compatible third-provider proof lane in sync so contributors add edge-case support through declared extension rules instead of editing shared imperative branching directly.
  priority: should
  stability: evolving
```

## Verification

```spec-verification
- kind: source_file
  target: README.md
  covers:
    - reqllm.workflow.beadwork_primed
    - reqllm.workflow.specled_loop

- kind: source_file
  target: AGENTS.md
  covers:
    - reqllm.workflow.agent_instructions

- kind: source_file
  target: .spec/README.md
  covers:
    - reqllm.workflow.specled_loop

- kind: source_file
  target: .spec/specs/workflow.spec.md
  covers:
    - reqllm.workflow.provider_surface_guides
    - reqllm.workflow.extension_dsl_guidance

- kind: source_file
  target: .spec/AGENTS.md
  covers:
    - reqllm.workflow.agent_instructions

- kind: command
  target: bw prime
  execute: true
  covers:
    - reqllm.workflow.beadwork_primed

- kind: command
  target: mix spec.prime --base HEAD
  execute: true
  covers:
    - reqllm.workflow.specled_loop
    - reqllm.workflow.agent_instructions

- kind: command
  target: mix test.starter_slice
  execute: true
  covers:
    - reqllm.workflow.starter_slice_verification

- kind: command
  target: mix test test/req_llm_next/extensions/dsl_test.exs
  execute: true
  covers:
    - reqllm.workflow.extension_dsl_guidance

- kind: command
  target: mix test test/req_llm_next/telemetry_test.exs test/req_llm_next/realtime_test.exs test/providers/deepseek
  execute: true
  covers:
    - reqllm.workflow.specled_loop
    - reqllm.workflow.agent_instructions
    - reqllm.workflow.extension_dsl_guidance
```
