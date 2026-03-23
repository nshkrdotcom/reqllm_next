# AGENTS.md - ReqLlmNext v2

**IMPORTANT: DO NOT WRITE COMMENTS INTO THE BODY OF ANY FUNCTIONS.**

## Work Management

<!-- covers: reqllm.workflow.agent_instructions -->

This repository tracks durable work with `bw` (Beadwork).

- Start every session with `bw prime`.
- Treat `bw` as the durable record for tickets, progress, and decisions that must survive session boundaries.
- This repo uses the `reqllm-XYZ` issue prefix.
- If `bw prime` reports uncommitted changes, assume they may belong to the user unless you can prove otherwise.

## Spec Led Workflow

- After `bw prime`, run `mix spec.prime --base HEAD` before editing current-truth package guidance.
- Keep `.spec/` as the canonical checked workflow layer for package and contributor contracts.
- Keep the existing `specs/` directory as supporting architecture and refactor context.
- After code, docs, or tests change, run `mix spec.next`.
- When the branch is ready, run `mix spec.check --base HEAD`.

## Engineering Posture

Read [`guides/package_thesis.md`](./guides/package_thesis.md) when you need the high-level rationale for how this repository is run.

The short version is:

1. agents are implementation accelerants, not the source of architectural truth
2. the source of truth is the combination of architecture docs, ADRs, checked `.spec/` subjects, scenario tests, fixtures, and compat tooling
3. do not collapse concerns for convenience; refactor spike code toward the documented boundaries instead
4. treat handcrafted `%LLMDB.Model{}` support, canonical API normalization, and the fixture/compat loop as product-level design decisions

## Package Overview

`ReqLlmNext` is a metadata-driven LLM client library for Elixir.

Public runtime entrypoints accept only:

1. an `LLMDB` `model_spec` string
2. an `%LLMDB.Model{}`

The default support path is metadata and policy from `LLMDB`. Handcrafted `%LLMDB.Model{}` values remain a first-class developer hook for local iteration, unreleased models, and local providers. The small set of irreducible quirks that still need code changes are handled through explicit adapters.

## Core Design Principles

1. **LLMDB is the preferred source of truth** - Model capabilities, limits, defaults, and surface facts flow from LLMDB metadata
2. **Narrow public model boundary** - Public runtime calls accept only `LLMDB` `model_spec` strings and `%LLMDB.Model{}`, including handcrafted model structs for local development
3. **Facts, mode, policy, and plan are separate** - `ModelProfile` is descriptive, `ExecutionMode` is request intent, policy rules resolve behavior, and `ExecutionPlan` is the only prescriptive object
4. **Execution surfaces are the support unit** - Endpoint styles are declared as named surfaces, not inferred from free combinations of protocol, wire format, and transport
5. **Deterministic implementation stacks** - A resolved plan must select one concrete stack of provider, session runtime, semantic protocol, wire format, transport, and plan adapters
6. **Separated execution layers** - Semantic protocol, wire format, transport, provider, session runtime, and adapters own different concerns
7. **Scenarios as capability tests** - Model-agnostic test scenarios validate capabilities through the public API
8. **Streaming-first** - All operations internally use streaming; non-streaming calls buffer the stream

## Architecture

<!-- covers: reqllm.architecture.model_input_boundary reqllm.architecture.facts_mode_policy_plan reqllm.architecture.execution_layers reqllm.layer_boundaries.plan_aware_adapters -->

```text
Public API
  -> Model Input Boundary
  -> Model Profile
  -> Execution Mode
  -> Policy Rules
  -> Execution Plan
  -> Operation Planner
  -> Semantic Protocol
  -> Wire Format
  -> Session Runtime
  -> Transport
  -> Provider
```

The current implementation still contains spike code, especially in `lib/req_llm_next/wire/` and the older adapter pipeline. Treat those as transitional code, not as the target architecture. Keep AGENTS focused on the current boundary model and contributor workflow; use [`guides/package_thesis.md`](./guides/package_thesis.md) for the broader package thesis and [`specs/`](./specs) for the detailed architecture contracts.
