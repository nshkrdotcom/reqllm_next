# Project Summary

Status: Working Summary

## Purpose

ReqLlmNext is the architectural spike for the next generation of ReqLLM.

The project is trying to solve two problems at once:

1. support a broad and changing model ecosystem without hard-coding model behavior into the core client
2. keep the architecture clean enough that model metadata, protocols, transports, sessions, and providers can evolve independently

The target is a client where production support is mostly metadata-driven, while local model iteration remains fast during development and testing.

## Architecture At A Glance

The current target architecture is:

```text
Public API
  -> Model Input Boundary
  -> Model Profile
  -> Operation Planner
  -> Semantic Protocol
  -> Session Runtime
  -> Transport
  -> Provider
```

This is a concern graph, not a rigid stack. Some concerns only participate for certain request types.

## Stable Decisions

### 1. Model input is flexible, but execution input is not

Public APIs may accept:

1. registry strings such as `"openai:gpt-5.4"`
2. `%LLMDB.Model{}`
3. local ReqLlmNext model structs
4. local naked maps

That flexibility is important because LLMDB is strong for production metadata, but too heavy for fast local iteration.

The important rule is that these are input forms only. After the boundary normalizes them, execution code should no longer see raw `%LLMDB.Model{}` values or raw local maps.

### 2. Runtime hard-fail is the enforcement model

The project is not leaning on macros or compile-time DSL enforcement.

The semantics are runtime-driven:

1. `%LLMDB.Model{}` is runtime data
2. local model maps are runtime data
3. provider and model behavior changes over time

So the boundary is enforced at runtime:

1. invalid input fails immediately
2. unknown keys fail
3. invalid combinations fail
4. user input must not create new atoms

`zoi` is the preferred validation tool for local descriptors and canonical profile validation.

### 3. Internal execution should stay small and canonical

The runtime model should stay centered on:

1. `model_input`
2. `%ModelProfile{}`
3. `%ExecutionPlan{}`

The profile should describe stable model facts in typed sections such as:

1. `operations`
2. `features`
3. `modalities`
4. `limits`
5. `defaults`
6. `constraints`

This is intentionally narrower than a loose capability bag. The goal is to keep facts descriptive and keep decisions in code.

### 4. Stable operation families and explicit execution boundaries

The model profile now describes stable operation families:

1. `:text`
2. `:object`
3. `:embedding`

Streaming is treated as a request mode, not as a separate model operation.

The planner owns interpretation:

1. map public API verbs to canonical operation families
2. validate operation and feature support
3. apply request-scoped constraints
4. choose protocol, transport, and session mode

Downstream execution layers should not re-interpret model facts.

The other key execution boundary is:

1. semantic protocol owns API meaning, payload shape, and event decoding
2. transport owns connection mechanics, framing, reconnect, and lifecycle
3. session runtime owns continuation ids, connection reuse, in-flight rules, and fallback
4. provider owns auth, endpoint roots, and provider-level common headers

Overrides should remain declarative, while adapters stay as a narrow escape hatch for behavior that metadata and overrides cannot express cleanly.

## Current Gap Between Code And Target

The codebase still reflects the earlier spike in places.

That spike proved useful ideas:

1. LLMDB is a strong metadata source
2. providers, wires, constraints, and adapters can be separated more than in the original ReqLLM
3. a more flexible architecture is possible

But the code still shows where the boundaries were too blurry:

1. wire and transport assumptions are still partially fused
2. executor still carries too much orchestration knowledge
3. raw `%LLMDB.Model{}` access is still present in runtime code
4. session-aware execution is not yet first-class in implementation

So the project is still in the clarification phase: tighten the contracts, reduce duplicated concepts, and then refactor toward the clarified target.

## Open Questions

The largest remaining design question is the execution-side handoff model.

In particular:

1. what exact object moves from planner to semantic protocol
2. what exact object moves from semantic protocol to transport
3. what exact inbound event shape transport returns upstream
4. how session runtime receives continuation updates without inspecting raw transport frames
5. how fixtures and replays should capture WebSocket conversations, not just SSE streams

The planner should remain one architectural boundary, but it does make sense to decompose it internally into smaller pure policy modules. That detail belongs primarily in [operation_planner.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/operation_planner.md).

## Summary

ReqLlmNext has moved from a promising metadata-driven spike toward a clearer architecture with stronger boundaries.

The most important decisions now look stable:

1. strict runtime model normalization
2. canonical `%ModelProfile{}` and `%ExecutionPlan{}`
3. planner-owned interpretation
4. semantic protocol separated from transport
5. session runtime treated as a first-class concern
6. local development supported without weakening production architecture

The next critical design step is to tighten the execution-side handoff contracts with the same discipline now applied to the model side.
