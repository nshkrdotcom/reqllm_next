# Package Thesis

Status: Working Guide

## Purpose

Explain how ReqLlmNext was imagined and why the package is being built the way it is.

This guide is intentionally higher-level than the architecture specs. The architecture specs define the contracts. This guide explains the package thesis that ties those contracts, the verification systems, and the development workflow together.

## Core Thesis

ReqLlmNext does use agents heavily.

But agents are not the source of truth.

The source of truth is the combination of:

1. documented architectural boundaries
2. durable ADRs and current-truth subjects
3. deterministic scenario tests against the canonical public API
4. fixture replay and live compatibility runs against real provider APIs
5. branch-time checks that force documentation and verification to stay aligned

Agents help produce code and documentation faster. They do not get to redefine correctness.

## Runtime Architecture In One Pass

The runtime model is intentionally small:

1. model source
   - either an `LLMDB` `model_spec` string or a handcrafted `%LLMDB.Model{}`

2. `ModelProfile`
   - descriptive model facts only

3. `ExecutionMode`
   - normalized request intent

4. `PolicyRules`
   - ordered provider, family, model, operation, and mode policy

5. `ExecutionPlan`
   - the single prescriptive runtime object

That plan then selects one deterministic implementation stack:

1. provider
2. session runtime
3. semantic protocol
4. wire format
5. transport
6. ordered plan adapters

Execution results are normalized back to the canonical ReqLlm API surface exposed from `ReqLlmNext`.

The point of this structure is not abstraction for its own sake. It is how the library can support a wide range of provider styles and edge cases without leaking one model's quirks into unrelated models.

## Why The Model Boundary Matters

The model boundary is intentionally narrow:

1. string input goes through `LLMDB` model resolution
2. handcrafted `%LLMDB.Model{}` input is still allowed

That second path is important.

It breaks the old coupling where trying a new model required landing catalog work in `LLMDB` first. It enables:

1. local iteration on unreleased models
2. provider experimentation before metadata is upstreamed
3. support for local providers such as Ollama

That flexibility is allowed only at the `%LLMDB.Model{}` boundary. ReqLlmNext still rejects tuples, ad hoc maps, and local descriptor shapes so the rest of the runtime can stay strict.

## Why The Execution Plan Matters

The key runtime decision is that provider access is not discovered piecemeal at call time.

Instead, the system produces one `ExecutionPlan` that determines:

1. which execution surface is primary
2. which fallbacks are valid
3. which parameters are normalized
4. which adapters apply
5. which layer implementations are used

That gives the system a deterministic, inspectable execution path.

If a model needs special behavior, that behavior should enter through:

1. descriptive model facts
2. explicit execution surfaces
3. ordered policy rules
4. explicit plan adapters

That is what keeps model-specific handling from silently affecting the rest of the matrix.

## The Reinforcing Systems

ReqLlmNext has several systems that reinforce this thesis.

### 1. Canonical Subject Specs

The `.spec/specs/` directory describes the intended architecture in human-readable, current-truth terms.

These subject specs are where the project captures:

1. boundary definitions
2. layer ownership
3. policy rules
4. session behavior
5. telemetry, diagnostics, and compat expectations

They are the architectural reference, not generated commentary.

### 2. Checked Current Truth

The same `.spec/` workspace is also the enforced contract layer.

It exists so the project does not rely on prose alone. The current-truth subjects:

1. name the active requirements
2. point to the relevant surfaces
3. link requirements to proof
4. force contributors and agents to reconcile docs, tests, and code during branch checks

This is what makes the architecture operational instead of aspirational.

### 3. Scenario Tests

Scenario tests exercise the public API in model-agnostic ways.

The goal is not merely to test internal functions. The goal is to prove that:

1. heterogeneous provider behavior can be driven through one canonical API
2. the normalization surface stays stable
3. capability support is validated at the API boundary users actually consume

That is why scenarios matter more than a large pile of provider-specific unit tests.

### 4. Fixture Replay

Fixtures are not just convenience mocks.

They are a first-class part of the package strategy:

1. live API behavior can be captured
2. replay makes regression tests deterministic
3. canonical normalization can be checked repeatedly without requiring live calls every test run
4. drift becomes observable over time

This matters because the library is only as good as its ability to normalize real, changing provider behavior into one consistent surface.

### 5. Live Compatibility And Drift Detection

ReqLlmNext is also intended to be a live compatibility system, not only a client library.

That means the project should be able to:

1. run shared scenarios against real models
2. capture structured diagnostics
3. classify anomalies by layer
4. detect provider drift
5. prepare evidence for follow-up work or issue filing

This is more advanced than ordinary ExUnit regression testing because it exercises the real layered runtime against real provider APIs.

### 6. Diagnostics And Telemetry

Compat work only stays useful if failures are attributable.

Diagnostics and telemetry exist so the project can answer questions like:

1. did planning choose the wrong surface
2. did a provider envelope change
3. did transport behavior drift
4. did a continuation/session contract break

Without that structure, every failure becomes just "model failed," which does not scale.

## The Role Of Agents

The project is agent-assisted by design.

That does not mean "let the model freestyle the architecture."

The intended use of agents here is:

1. accelerate synthesis across a large design space
2. draft and refine code under explicit architectural constraints
3. keep documentation, tests, and implementation moving together
4. reduce mechanical toil so more effort goes into boundary quality

What agents should not do:

1. invent new architecture because a local shortcut feels convenient
2. collapse concerns back together because the spike code does
3. replace the role of specs, ADRs, tests, fixtures, or compat evidence

In other words, agents are part of the delivery system. They are not the authority.

## What This Buys The Package

This approach is trying to buy a few very specific properties:

1. broad provider and model support with limited blast radius for quirks
2. local experimentation without first editing the catalog
3. deterministic and inspectable execution behavior
4. a canonical API surface that can survive provider churn
5. regression protection against drift in live APIs
6. a development process where agent speed is constrained by real engineering guardrails

## Summary

ReqLlmNext is not trying to prove that agents can replace software engineering.

It is trying to prove that a strong architecture, explicit specs, deterministic planning, scenario tests, fixture replay, and live compatibility tooling can let agents participate in building quality software without making correctness depend on LLM randomness.
