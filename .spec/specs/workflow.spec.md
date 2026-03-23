# Contributor Workflow

Repository workflow contract for Beadwork and Spec Led Development.

```spec-meta
id: reqllm.workflow
kind: workflow
status: active
summary: Contributor workflow contract for durable work tracking and current-truth maintenance.
surface:
  - README.md
  - AGENTS.md
  - mix.exs
```

## Requirements

```spec-requirements
- id: reqllm.workflow.beadwork_primed
  statement: Contributor and agent workflows shall start by loading Beadwork context so durable work state survives session boundaries.
  priority: must
  stability: evolving

- id: reqllm.workflow.specled_loop
  statement: Contributor workflow shall keep a canonical .spec workspace and use mix spec.prime, mix spec.next, and mix spec.check to maintain current truth alongside the existing specs/ architecture notes.
  priority: must
  stability: evolving

- id: reqllm.workflow.agent_instructions
  statement: Repository agent instructions shall direct agents to run bw prime before work and mix spec.prime --base HEAD before editing current-truth package guidance.
  priority: must
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
```
