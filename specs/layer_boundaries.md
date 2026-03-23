# Layer Boundaries Spec

Status: Proposed

<!-- covers: reqllm.layer_boundaries.separated_io reqllm.layer_boundaries.plan_aware_adapters -->

## Objective

Define the explicit handoff contracts between planning and the execution layers.

## Purpose

ReqLlmNext can support many providers and endpoint styles only if each layer has a small, explicit input and output contract.

## Boundary Contracts

1. Provider
   - input: provider identity plus environment/config state
   - output: `ProviderContext`
   - owns auth and endpoint roots only

2. Transport
   - input: `ExecutionPlan`, `ProviderContext`, outbound wire request, optional session handle
   - output: raw frames or response bodies plus lifecycle signals
   - owns connection mechanics only

3. Wire Format
   - input: `ExecutionPlan` plus semantic payload
   - output: outbound transport request and parsed provider-family event terms
   - owns routes, content types, envelopes, and raw frame parsing

4. Semantic Protocol
   - input: `ExecutionPlan` plus optional session state
   - output: semantic payloads and canonical chunks
   - owns API-family meaning only

5. Session Runtime
   - input: `ExecutionPlan`, session references, terminal metadata
   - output: session handles and continuation updates
   - owns persistent execution state only

## Separation Rule

No layer may skip across another layer's ownership boundary.

Examples:

1. semantic protocol must not choose a transport
2. wire format must not reinterpret semantic meaning
3. transport must not parse semantic events
4. provider must not choose model-specific behavior

## Adapter Rule

Adapters must be layer-scoped.

ReqLlmNext v2 starts with `PlanAdapter`:

1. input: `ExecutionPlan`
2. output: `ExecutionPlan`
3. purpose: narrow imperative patches for behavior metadata and rules cannot express cleanly

If protocol-level or wire-format-level adapters are ever added later, they must be separate explicit adapter behaviors. A single omniscient adapter pipeline is not a target architecture.

## Example Handoff

1. planner emits `ExecutionPlan` with `:responses_ws_text`
2. semantic protocol builds a Responses payload
3. wire format wraps it in `response.create`
4. transport sends it on WebSocket
5. transport returns raw frames
6. wire format parses those frames into provider-family events
7. semantic protocol decodes them into canonical chunks
