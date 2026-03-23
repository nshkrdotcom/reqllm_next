# Architecture Spec

Status: Proposed

<!-- covers: reqllm.architecture.model_input_boundary reqllm.architecture.facts_mode_policy_plan reqllm.architecture.execution_layers -->

## Objective

Define a clean, explicit boundary model so ReqLlmNext can:

1. execute model requests cleanly across providers, semantic protocols, wire formats, transports, and session strategies
2. verify live model compatibility through pressure tests without coupling compat logic into runtime layers
3. support many endpoint styles and model quirks without turning planning into model-name branching
4. keep the public runtime input boundary narrow so execution stays canonical

## Design Principles

1. LLMDB is the preferred source of model metadata truth in production.
2. Raw model metadata is accepted only at the boundary and must be normalized before execution.
3. Invalid model metadata must hard-fail at runtime. There is no best-effort fallback after normalization.
4. Each layer owns one concern and exposes one contract.
5. `ModelProfile` is descriptive, not prescriptive.
6. `ExecutionMode` is a first-class normalized request object.
7. `ExecutionSurface` is the stable support unit for endpoint styles.
8. Policy resolution is rule-based across provider, family, model, operation, and mode scopes.
9. Semantic protocol, wire format, and transport are separate concerns.
10. Session state is first-class for APIs that support or require continuation.
11. Model compatibility testing is a first-class consumer of the architecture, not a side utility.
12. Every anomaly should map to an obvious layer-owned source location.

## Concern Stack

```
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

Layer-scoped adapters may patch the plan after policy resolution.

Model Compat consumes the same contracts plus diagnostics.
```

This is a concern graph, not a strict call stack.

1. `Model Input Boundary`, `Model Profile`, `Execution Mode`, `Policy Rules`, and `Execution Plan` are the main normalization pipeline.
2. `Operation Planner` owns mode normalization, policy evaluation, and plan assembly.
3. `Session Runtime` participates only when the plan requires continuation or transport reuse.
4. `Provider`, `Semantic Protocol`, `Wire Format`, and `Transport` collaborate during execution.
5. Layer-scoped adapters are patch points, not alternative execution layers.

## Concern Purpose

1. Model Input Boundary
   - Accept public model inputs.
   - Interpret `LLMDB` `model_spec` strings and `%LLMDB.Model{}` values only.
   - Translate all valid inputs into a canonical internal representation.
   - Reject unsupported input types immediately.

2. Model Profile
   - Resolve validated model input into a canonical, descriptive profile.
   - Merge LLMDB metadata with static profile facts and descriptive metadata.
   - Expose operation families, features, limits, modalities, parameter defaults, constraints metadata, and supported execution surfaces.
   - Must not contain request payloads, connections, or prompt state.

3. Execution Mode
   - Normalize public API intent and mode-affecting request hints into a typed request-mode object.
   - Describe whether the request is streaming, tool-using, structured, session-oriented, long-running, or multimodal.
   - Must not contain provider payloads or resolved endpoint choices.

4. Policy Rules
   - Evaluate ordered match-and-patch rules across provider, family, model, operation, and mode scopes.
   - Choose preferred and fallback execution surfaces plus plan defaults.
   - Must not invent capability that the profile does not describe as supported.

5. Execution Plan
   - Capture the fully resolved runtime behavior for one attempt.
   - Select one execution surface plus timeout, session, fallback, normalized parameters, and adapter patches.
   - Must be the only prescriptive object consumed by downstream execution layers.

6. Operation Planner
   - Own the orchestration that turns `ModelProfile`, `ExecutionMode`, and `PolicyRules` into `ExecutionPlan`.
   - Perform validation and request-scoped parameter normalization.
   - Must not perform I/O or payload encoding.

7. Semantic Protocol
   - Define the meaning of a provider API family.
   - Encode canonical execution plans into protocol payloads.
   - Decode provider-family events into canonical chunks.
   - Must not own routes, envelopes, sockets, HTTP clients, retries, or reconnect policy.

8. Wire Format
   - Translate semantic protocol payloads into transport-facing requests or client events.
   - Own relative routes, content types, wire envelopes, and inbound frame decoding.
   - Must not reinterpret semantic meaning or own connection lifecycle.

9. Session Runtime
   - Manage persistent execution state across turns.
   - Own continuation identifiers, connection reuse, in-flight rules, and session expiry.
   - Must not own protocol payload shape or wire envelopes.

10. Transport
   - Move bytes and transport frames.
   - Own connection lifecycle, keepalive, reconnect, and backpressure.
   - Support at least `:http`, `:http_sse`, and `:websocket`.
   - Must not own model-specific behavior or wire-format envelopes.

11. Provider
   - Own auth strategy, base URL, provider headers, and key lookup.
   - Own endpoint roots for transports.
   - Must not own model-specific rules, request payload shape, or event decoding.

12. Layer-Scoped Adapters
   - Provide explicit imperative customization points after policy resolution.
   - Start with plan-aware adapters that patch `ExecutionPlan`.
   - Additional adapter kinds must stay layer-scoped and explicit.
   - Must not become global raw-model mutation hooks.

13. Model Compat
   - Run live allow-listed compatibility and pressure-test scenarios against real provider APIs.
   - Classify anomalies by architectural layer.
   - Produce structured evidence and issue drafts without patching runtime behavior.

14. Diagnostics
   - Emit structured decision and execution evidence for planning, protocol, transport, and session behavior.
   - Support anomaly attribution and issue filing without requiring ad hoc log scraping.

## Core Internal Rule

Inside execution code, the system should be reduced to four core runtime objects plus one durable policy input:

1. `model_input`
   - Public input only
   - String spec or `%LLMDB.Model{}`

2. `ModelProfile`
   - Canonical validated model facts

3. `ExecutionMode`
   - Canonical normalized request mode

4. `ExecutionPlan`
   - Request-specific resolved behavior

5. `PolicyRules`
   - Durable rule inputs consumed during plan assembly

Raw `%LLMDB.Model{}` values must not survive past the model input boundary.

`ModelProfile` should describe stable model facts only.

`ExecutionMode` should describe normalized request characteristics only.

`ExecutionPlan` should be the only object that says exactly how the request will run.

Model compat and pressure-test tooling must consume these same canonical runtime shapes rather than introducing private shortcuts around them.

## Canonical Contracts

1. Model profile
   - Serializable, stable, request-independent profile derived from metadata.
   - Describes supported execution surfaces but does not select one.

2. Execution mode
   - Serializable, request-scoped normalized mode facts derived from API intent and mode hints.

3. Policy rules
   - Ordered declarative rules that match on provider, family, model, operation, and mode.

4. Execution plan
   - Request-scoped, validated, and fully resolved plan for a single operation attempt.
   - Includes one chosen execution surface, normalized parameters, session policy, fallback surfaces, and adapter refs.

5. Canonical stream chunk shape
   - Binary text chunks
   - `{:tool_call_start, map}`
   - `{:tool_call_delta, map}`
   - `{:thinking, binary}`
   - `{:usage, map}`
   - `{:meta, map}`
   - `{:error, map}`

6. Canonical transport error shape
   - `%ReqLlmNext.Error.API.Request{}` for connection/protocol failures
   - `%ReqLlmNext.Error.API.Stream{}` for stream processing failures

## Common Execution Ordering

1. Accept `model_input` from the public API.
2. Validate and normalize it through the model input boundary.
3. Resolve it into a `ModelProfile`.
4. Normalize API intent and mode-affecting hints into `ExecutionMode`.
5. Evaluate `PolicyRules` against `ModelProfile` and `ExecutionMode`.
6. Assemble the resulting `ExecutionPlan`.
7. Apply plan-aware adapters if required.
8. Acquire or attach a `SessionRuntime` if required.
9. Encode the plan through the selected `SemanticProtocol`.
10. Encode the semantic payload through the selected `WireFormat`.
11. Execute through the selected `Transport`.
12. Decode inbound transport frames through the `WireFormat`.
13. Decode provider-family events through the `SemanticProtocol`.
14. Update `SessionRuntime` from terminal and continuation metadata.
15. Materialize or stream the canonical response.

## Spec Map

1. [enforcement.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/enforcement.md)
2. [model_compat.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/model_compat.md)
3. [diagnostics.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/diagnostics.md)
4. [telemetry.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/telemetry.md)
5. [layer_boundaries.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/layer_boundaries.md)
6. [source_layout.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/source_layout.md)
7. [model_source.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/model_source.md)
8. [model_profile.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/model_profile.md)
9. [execution_mode.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/execution_mode.md)
10. [execution_surface.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/execution_surface.md)
11. [overrides.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/overrides.md)
12. [execution_plan.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/execution_plan.md)
13. [operation_planner.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/operation_planner.md)
14. [semantic_protocol.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/semantic_protocol.md)
15. [wire_format.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/wire_format.md)
16. [session_runtime.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/session_runtime.md)
17. [transport.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/transport.md)
18. [provider.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/provider.md)

## Non-Goals

1. Execution modules reading raw `%LLMDB.Model{}`.
2. `ModelProfile` choosing concrete endpoint behavior for a request.
3. Policy rules inventing capability that the profile does not support.
4. Provider modules selecting model-specific behavior.
5. Semantic protocol modules handling connection lifecycle.
6. Wire format modules reinterpreting semantic request meaning.
7. Transport modules rewriting wire-format envelopes.
8. Omniscient global adapters mutating raw model input before planning.
9. Model compat or issue-filing logic mutating runtime execution behavior.
