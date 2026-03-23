# Project Summary

Status: Working Summary

## Purpose

ReqLlmNext is the architectural spike for the next generation of ReqLLM.

The project is trying to solve two problems at once:

1. support a broad and changing model ecosystem without hard-coding model behavior into the core client
2. keep the architecture clean enough that model facts, execution modes, policy rules, surfaces, sessions, protocols, wire formats, transports, and providers can evolve independently

The target is a client where production support is mostly metadata-driven while the public runtime boundary stays narrow and explicit.

It now also has a second primary purpose: act as the live model compatibility and pressure-test harness for the ReqLLM ecosystem.

## Architecture At A Glance

The current target architecture is:

```text
Public API
  -> Model Input Boundary
  -> Model Profile
  -> Execution Mode
  -> Policy Rules
  -> Execution Plan
  -> Operation Planner
  -> Session Runtime
  -> Semantic Protocol
  -> Wire Format
  -> Transport
  -> Provider
```

This is a concern graph, not a rigid stack. Some concerns only participate for certain request types.

The same architecture is meant to serve two consumers:

1. runtime model execution
2. live model compatibility verification

## Stable Decisions

### 1. Model input is narrow

Public APIs may accept:

1. registry strings such as `"openai:gpt-5.4"`
2. `%LLMDB.Model{}`

The important rule is that these are input forms only. After the boundary normalizes them, execution code should no longer see raw `%LLMDB.Model{}` values.

### 2. Model profile is descriptive, not prescriptive

`ModelProfile` exists to describe stable model facts:

1. operation-family support
2. features and modalities
3. limits and parameter defaults
4. constraints metadata
5. supported execution surfaces

It must not decide which endpoint style a particular request should use.

### 3. Execution surface is the unit of endpoint support

Support is not a cartesian product of protocol, wire format, and transport lists.

The stable support unit is an `ExecutionSurface`: one valid endpoint style for one operation family on one model.

That is what lets ReqLlmNext support multiple provider styles and endpoints cleanly without treating every dimension as independently choosable.

### 4. Execution mode is a first-class normalized request object

Public request inputs should be split into:

1. mode hints that affect endpoint selection and session policy
2. generation parameters that affect payload content once a surface is chosen

Those mode hints normalize into `%ExecutionMode{}` before policy resolution.

### 5. Runtime hard-fail is the enforcement model

The project is not leaning on macros or compile-time DSL enforcement.

The semantics are runtime-driven:

1. `%LLMDB.Model{}` is runtime data
2. provider and model behavior changes over time

So the boundary is enforced at runtime:

1. invalid input fails immediately
2. unknown keys fail
3. invalid combinations fail
4. user input must not create new atoms

`zoi` is the preferred validation tool for canonical profile validation and strict override/config schemas.

### 6. Internal execution should stay small and canonical

The runtime model should stay centered on:

1. `ModelRef`
2. `%ModelProfile{}`
3. `%ExecutionMode{}`
4. `%ExecutionPlan{}`

Policy rules are durable configuration consumed between mode normalization and plan assembly. The goal is to keep facts descriptive, policy declarative, and the final plan explicit.

### 7. Planner-owned policy should be rule-based, not ad hoc merge-based

The planner owns interpretation:

1. map public API verbs to operation families
2. normalize request mode
3. evaluate ordered policy rules across provider, family, model, operation, and mode scopes
4. choose an execution surface
5. apply parameter normalization and fallbacks

Downstream layers should receive resolved choices, not repeat model interpretation.

### 8. Explicit execution boundaries still matter

The key execution boundary is:

1. session runtime owns persistent continuation and reuse state
2. semantic protocol owns API-family meaning and canonical event decoding
3. wire format owns provider-facing routes, envelopes, and inbound frame parsing
4. transport owns connection mechanics and byte or frame movement
5. provider owns auth and endpoint roots

Adapters stay as a narrow escape hatch, but they should be plan-aware and layer-scoped rather than raw-model global hooks.

The same layered ownership is also what makes a large compatibility-testing ecosystem sustainable. If a live pressure test finds an anomaly, there should be an obvious place in the source tree where that issue belongs.

## Current Gap Between Code And Target

The codebase still reflects the earlier spike in places.

That spike proved useful ideas:

1. LLMDB is a strong metadata source
2. providers, wires, constraints, and adapters can be separated more than in the original ReqLLM
3. a more flexible architecture is possible

But the code still shows where the boundaries were too blurry:

1. semantic protocol, wire format, and transport assumptions are still partially fused inside the current `Wire.*` modules
2. there is no first-class `ExecutionMode`
3. support is still described too much as merged defaults instead of selected surfaces
4. policy is not yet expressed as ordered five-scope rules
5. adapters still look too much like raw-model option mutators
6. raw `%LLMDB.Model{}` access is still present in runtime code

The other missing piece is diagnostic structure. For model compatibility pressure tests to remain useful at scale, anomalies need to be attributable by layer rather than just reported as generic model failures.

So the project is still in the clarification phase: tighten the contracts, reduce duplicated concepts, and then refactor toward the clarified target.

## Open Questions

The largest remaining design question is the execution-side handoff model.

In particular:

1. how rich `ExecutionMode` should be without becoming a bag of raw opts
2. how `ExecutionSurface` should express session support, fallbacks, and feature tags
3. how policy patches should be constrained so they cannot invent unsupported capability
4. how far layer-scoped adapters should go beyond plan adapters
5. how fixtures and replays should capture WebSocket conversations, not just SSE streams

There is also a parallel ecosystem question:

1. how live pressure-test scenarios should be structured
2. how anomalies should be classified by layer
3. how issue filing should consume structured evidence without leaking into runtime layers

The planner should remain one architectural boundary, but it does make sense to decompose it internally into smaller pure policy modules. That detail belongs primarily in [operation_planner.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/operation_planner.md).

## Summary

ReqLlmNext has moved from a promising metadata-driven spike toward a clearer architecture with stronger boundaries.

The most important decisions now look stable:

1. strict runtime model normalization
2. descriptive `%ModelProfile{}`
3. first-class `%ExecutionMode{}`
4. `ExecutionSurface` as the unit of endpoint support
5. planner-owned five-scope policy resolution
6. `%ExecutionPlan{}` as the only prescriptive runtime object
7. semantic protocol separated from wire format and transport
8. session runtime treated as a first-class concern
9. model compatibility treated as a first-class architecture consumer

The next critical design step is to encode these contracts into current-truth architecture subjects and then refactor the spike implementation toward them one layer at a time.
