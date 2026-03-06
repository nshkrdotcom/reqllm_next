# Architecture Spec

Status: Proposed

## Objective

Define a clean, explicit boundary model so ReqLlmNext can add providers, models, protocols, transports, and session strategies without coupling concerns, while still supporting local model descriptors during development and testing.

## Design Principles

1. LLMDB is the preferred source of model metadata truth in production.
2. Raw model metadata is accepted only at the boundary and must be normalized before execution.
3. Invalid model metadata must hard-fail at runtime. There is no best-effort fallback after normalization.
4. Each layer owns one concern and exposes one contract.
5. Semantic protocol and transport are separate concerns.
6. Session state is first-class for APIs that support or require continuation.
7. Local model descriptors are first-class development inputs, not ad hoc hacks.

## Concern Stack

```
Public API
  -> Model Input Boundary
  -> Model Profile
  -> Operation Planner
  -> Semantic Protocol
  -> Session Runtime
  -> Transport
  -> Provider

Overrides and Adapters feed Model Profile and Operation Planner.
```

This is a concern graph, not a strict call stack.

1. `Model Input Boundary`, `Model Profile`, and `Operation Planner` are the main normalization pipeline.
2. `Session Runtime` participates only when the plan requires continuation or transport reuse.
3. `Provider`, `Semantic Protocol`, and `Transport` collaborate during execution.
4. Adapters and overrides are policy inputs, not first-class execution layers.

## Concern Purpose

1. Model Input Boundary
   - Accept public model inputs.
   - Interpret registry specs, `%LLMDB.Model{}` values, local structs, and raw maps.
   - Validate local descriptors under a closed schema.
   - Translate all valid inputs into a canonical internal representation.
   - Reject unknown keys, unknown enum values, and invalid combinations.

2. Model Profile
   - Resolve validated model input into a canonical, execution-ready profile.
   - Merge LLMDB metadata with configured provider/model overrides.
   - Expose operation families, features, limits, defaults, modalities, constraints metadata, and adapter config.
   - Must not contain request payloads, connections, or prompt state.

3. Operation Planner
   - Convert a public API call plus request options into a canonical execution plan.
   - Perform validation and request-scoped constraint application.
   - Select semantic protocol, transport, session mode, and fallback policy.
   - Must not perform I/O or payload encoding.

4. Semantic Protocol
   - Define the meaning of a provider API family.
   - Encode canonical request plans into protocol payloads.
   - Decode provider-family events into canonical chunks.
   - Must not own sockets, HTTP clients, retries, or reconnect policy.

5. Session Runtime
   - Manage persistent execution state across turns.
   - Own continuation identifiers, connection reuse, in-flight rules, and session expiry.
   - Must not own protocol payload shape.

6. Transport
   - Move bytes and frames.
   - Own connection lifecycle, framing, keepalive, reconnect, and backpressure.
   - Support at least `:http`, `:http_sse`, and `:websocket`.
   - Must not own model-specific behavior.

7. Provider
   - Own auth strategy, base URL, provider headers, and key lookup.
   - Own endpoint roots for transports.
   - Must not own model-specific rules, request payload shape, or event decoding.

8. Overrides and Adapters
   - Provide declarative and imperative customization points.
   - Overrides are preferred for static provider/model/family policy.
   - Adapters exist only for behavior that metadata and overrides cannot express cleanly.

## Core Internal Rule

Inside execution code, the system should be reduced to three core objects:

1. `model_input`
   - Public input only
   - String spec, `%LLMDB.Model{}`, local struct, or local map

2. `ModelProfile`
   - Canonical validated model facts

3. `ExecutionPlan`
   - Request-specific resolved behavior

Raw `%LLMDB.Model{}` values and raw local maps must not survive past the model input boundary.

`ModelProfile` should describe stable model facts. Request modes such as `stream?` belong in `ExecutionPlan`, not in the profile.

## Canonical Contracts

1. Model profile
   - Serializable, stable, request-independent profile derived from metadata and configured overrides.

2. Execution plan
   - Request-scoped, validated, and fully resolved plan for a single operation attempt.

3. Canonical stream chunk shape
   - Binary text chunks
   - `{:tool_call_start, map}`
   - `{:tool_call_delta, map}`
   - `{:thinking, binary}`
   - `{:usage, map}`
   - `{:meta, map}`
   - `{:error, map}`

4. Canonical transport error shape
   - `%ReqLlmNext.Error.API.Request{}` for connection/protocol failures
   - `%ReqLlmNext.Error.API.Stream{}` for stream processing failures

## Common Execution Ordering

1. Accept `model_input` from the public API.
2. Validate and normalize it through the model input boundary.
3. Resolve it into a `ModelProfile`.
4. Plan the operation into an `ExecutionPlan`.
5. Acquire or attach a `SessionRuntime` if required.
6. Encode the plan through the selected `SemanticProtocol`.
7. Execute through the selected `Transport`.
8. Decode inbound provider events through the `SemanticProtocol`.
9. Update `SessionRuntime` from terminal and continuation metadata.
10. Materialize or stream the canonical response.

## Spec Map

1. [enforcement.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/enforcement.md)
2. [model_source.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/model_source.md)
3. [model_profile.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/model_profile.md)
4. [operation_planner.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/operation_planner.md)
5. [semantic_protocol.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/semantic_protocol.md)
6. [session_runtime.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/session_runtime.md)
7. [transport.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/transport.md)
8. [provider.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/provider.md)
9. [overrides.md](/Users/mhostetler/Source/ReqLLM/reqllm_next/specs/overrides.md)

## Non-Goals

1. Execution modules reading raw `%LLMDB.Model{}` or raw local maps.
2. Provider modules selecting model-specific behavior.
3. Semantic protocol modules handling connection lifecycle.
4. Transport modules rewriting semantic request structure.
5. Adapters mutating provider identity or transport handles.
