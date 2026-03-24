# Contributor Workflow

Repository workflow contract for Beadwork and Spec Led Development.

<!-- covers: reqllm.workflow.beadwork_primed reqllm.workflow.specled_loop reqllm.workflow.agent_instructions reqllm.workflow.starter_slice_verification -->

```spec-meta
id: reqllm.workflow
kind: workflow
status: active
summary: Contributor workflow contract for durable work tracking, current-truth maintenance, and keeping contributor docs aligned with the Spec Led workspace, including the public model-input boundary contract and the repo's package-thesis narrative.
surface:
  - README.md
  - AGENTS.md
  - .spec/README.md
  - .spec/AGENTS.md
  - guides/package_thesis.md
  - guides/anthropic_surface_map.md
  - mix.exs
```

## Requirements

```spec-requirements
- id: reqllm.workflow.beadwork_primed
  statement: Contributor and agent workflows shall start by loading Beadwork context so durable work state survives session boundaries.
  priority: must
  stability: evolving

- id: reqllm.workflow.specled_loop
  statement: Contributor workflow shall keep `.spec/` as the canonical spec workspace and use `mix spec.prime`, `mix spec.next`, and `mix spec.check` to maintain the subject specs, ADRs, README, AGENTS, and package-thesis guide in sync with current truth.
  priority: must
  stability: evolving

- id: reqllm.workflow.agent_instructions
  statement: Repository agent instructions shall direct agents to run bw prime before work and mix spec.prime --base HEAD before editing current-truth package guidance.
  priority: must
  stability: evolving

- id: reqllm.workflow.starter_slice_verification
  statement: Contributor workflow shall provide named verification entry points for the current starter-model slices and curated provider support-matrix lanes so replay-backed checks, live fixture refreshes, websocket coverage, and provider-feature probes use explicit shared paths.
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
```
