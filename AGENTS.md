# AGENTS.md - ReqLlmNext v2

**IMPORTANT: DO NOT WRITE COMMENTS INTO THE BODY OF ANY FUNCTIONS.**

## Work Management

<!-- covers: reqllm.workflow.agent_instructions -->

This repository uses `bw` (Beadwork) as the durable work tracker.

- Start every session with `bw prime`.
- Treat `bw` as the long-lived record for tasks, progress, and decisions that must survive agent hand-offs.
- This repo uses the `reqllm-XYZ` issue prefix.
- If `bw prime` reports uncommitted changes, assume they may belong to the user unless you can prove otherwise.

## Spec Led Workflow

After `bw prime`, run `mix spec.prime --base HEAD` before editing package guidance, architecture notes, or current-truth docs.

- Keep `.spec/` as the canonical spec workspace.
- Treat `.spec/specs/*.spec.md` as the source of current architectural truth.
- After code, docs, or tests change, run `mix spec.next`.
- When the branch is ready, run `mix spec.check --base HEAD`.
- Use `mix spec.status` when you need coverage or frontier summaries.

## Engineering Posture

Read [`guides/package_thesis.md`](./guides/package_thesis.md) when you need the high-level rationale for the package.

The short version is:

1. agents accelerate implementation, but they are not the source of truth
2. the source of truth is the combination of `.spec` subjects, ADRs, public API tests, scenario tests, fixtures, and compat tooling
3. do not collapse concerns for convenience; reconcile spike-era code toward the documented boundaries instead
4. treat handcrafted `%LLMDB.Model{}` input, canonical API normalization, and the fixture and compat loop as product-level design decisions
5. treat package-owned structs as schema contracts and standardize them on Zoi

## Hard Package Boundaries

`ReqLlmNext` is the hard public facade for the package.

- Preserve the top-level ReqLLM-style API in `lib/req_llm_next.ex`.
- Keep `ReqLlmNext` thin. Do not add provider, wire, transport, fixture, or utility branching logic to the facade.
- Public runtime entrypoints accept only:
  1. an `LLMDB` `model_spec` string
  2. an `%LLMDB.Model{}`
- Handcrafted `%LLMDB.Model{}` values are a first-class developer hook for local iteration, unreleased models, and local providers.
- Provider-native utility endpoints belong in provider-scoped modules such as `ReqLlmNext.Anthropic`, not in the top-level cross-provider facade.

## Runtime Model

<!-- covers: reqllm.architecture.model_input_boundary reqllm.architecture.facts_mode_policy_plan reqllm.architecture.execution_layers reqllm.layer_boundaries.plan_aware_adapters -->

ReqLlmNext is built around a deterministic planning model:

```text
ReqLlmNext facade
  -> ModelResolver
  -> ModelProfile
  -> ExecutionMode
  -> PolicyRules
  -> OperationPlanner
  -> ExecutionPlan
  -> ExecutionModules
  -> Session Runtime
  -> Semantic Protocol
  -> Wire Format
  -> Transport
  -> Provider
  -> canonical Response / StreamResponse
```

The key runtime rules are:

1. `ModelProfile` is descriptive only
2. `ExecutionMode` captures normalized request intent
3. `ExecutionPlan` is the single prescriptive runtime object
4. one resolved plan must select one deterministic execution stack
5. explicit transport choice must be honored when a matching surface exists
6. surface-specific parameter validation belongs before wire encoding, not as quiet mutation deeper in the stack

## Layer Ownership

Use the layers for their intended concerns.

- `Session Runtime`: persistent execution state such as continuation or response reuse
- `Semantic Protocol`: canonical meaning and event normalization for an API family
- `Wire Format`: provider JSON bodies, streaming frames, and raw envelope parsing
- `Transport`: HTTP streaming, WebSocket, and related byte movement concerns
- `Provider`: base URLs, auth, and provider-root request policy
- `Adapters`: narrow, explicit, plan-aware escape hatches for irreducible quirks after policy resolution
- Provider utilities: non-canonical endpoints that should not expand the top-level facade

Do not push provider-specific behavior upward into shared layers when it can live in provider, protocol, wire, transport, or provider-utility code instead.

## Provider-Specific Work

Prefer new support in this order:

1. `LLMDB` metadata
2. `ModelProfile` facts and declared `ExecutionSurface`s
3. policy rules and planner validation
4. semantic protocol, wire, transport, or provider implementations
5. explicit adapters
6. provider-scoped utility modules for non-canonical endpoints

Guardrails:

- Do not add provider-name branching to the top-level facade.
- Do not let provider-native request shapes leak across providers through shared opts or raw maps.
- Do not put provider-specific request shaping into shared executor code when it can be expressed as planning, provider, protocol, or wire ownership.
- Keep provider-native helpers scoped to the owning provider so OpenAI and Anthropic quirks do not contaminate each other.

## Verification System

The verification model is part of the architecture.

- `test/public_api/` protects the hard top-level package contract.
- `test/scenarios/` exercises capability scenarios through the public API.
- `test/model_slices/` holds a small curated set of anchor models, not a one-file-per-model matrix.
- `lib/req_llm_next/support_matrix.ex` and `test/coverage/` define broader curated provider lanes.
- `test/provider_features/` holds focused provider feature probes such as beta or transport-specific coverage.
- `test/fixtures/` stores replay artifacts. Replay is the default test mode.

Fixtures are first-class evidence, not just mocks.

- Record with `REQ_LLM_NEXT_FIXTURES_MODE=record`.
- Replay should preserve the recorded execution surface even if the live planner would choose a newer surface today.
- Use live runs carefully and keep them curated.

## Commands

Common commands:

```bash
bw prime
mix spec.prime --base HEAD
mix test
mix test test/public_api
mix test test/scenarios
mix test.starter_slice
mix spec.next
mix spec.check --base HEAD
```

When live API keys are available and you need fresh fixtures:

```bash
REQ_LLM_NEXT_FIXTURES_MODE=record mix test.starter_slice
```

## Practical Rules

- Preserve public API parity before refining internals.
- Keep execution-plan behavior deterministic and inspectable.
- Prefer small, explicit surfaces over hidden branching.
- Keep provider-specific expansion explainable in guides, specs, and tests.
- Any package-owned struct in `lib/req_llm_next` should be Zoi-backed unless there is a very strong reason it cannot be.
- When a new struct is added, prefer a Zoi schema, Zoi-backed enforce keys, and constructor helpers such as `schema/0`, `new/1`, and `new!/1` when they add practical value.
- If a change is cross-cutting and durable, update the relevant ADR.
- If a change affects current truth, reconcile `.spec` in the same branch.
