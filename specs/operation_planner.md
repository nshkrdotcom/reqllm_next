# Operation Planner Spec

Status: Proposed

## Objective

Define how a public API request becomes a validated, fully resolved execution plan.

## Purpose

The planner is the policy layer. It decides how a request should run without performing any I/O.

It is also the main interpreter of model facts. Downstream execution layers should receive resolved choices, not raw capability data.

This should remain one ownership boundary, but it does make sense to implement it as several smaller pure policy modules and intermediate structs.

## Responsibilities

1. Accept a public API request, `ModelProfile`, request options, and optional session context.
2. Resolve request intent into an operation family and request mode.
3. Validate operation compatibility and modality requirements.
4. Apply request-scoped constraint normalization.
5. Merge request options with model defaults.
6. Select semantic protocol, transport, streaming mode, and session mode.
7. Produce a canonical `ExecutionPlan`.

## Inputs

1. API intent
   - `:generate_text`
   - `:stream_text`
   - `:generate_object`
   - `:stream_object`
   - `:embed`
2. `ModelProfile`
3. Prompt or context
4. Request options
5. Optional session reference

## Output Shape

```elixir
%ExecutionPlan{
  operation: :text,
  stream?: true,
  prompt: canonical_prompt,
  model: model_profile,
  provider: :openai,
  semantic_protocol: :openai_responses,
  transport: :websocket,
  session_mode: :attach_or_create,
  continuation_strategy: :previous_response_id,
  normalized_opts: %{...},
  timeout_ms: 300_000,
  fallback: %{transport: :http_sse, on: [:session_unavailable, :websocket_rejected]}
}
```

## Invariants

1. Planning must be side-effect free.
2. The planner must never encode provider payloads.
3. The planner must never open sockets or send requests.
4. The planner must return structured errors, not partially executed work.
5. The planner must consume `%ModelProfile{}` only, not raw `%LLMDB.Model{}` or local maps.
6. The planner and validation logic are the only layers allowed to interpret operation and feature support from the profile.

## Recommended Internal Decomposition

One planner boundary can still be built from smaller internal modules or little structs.

Recommended pure sub-concerns:

1. `IntentPolicy`
   - maps public API intent into an operation family and request mode
   - example: `:stream_text -> %{operation: :text, stream?: true}`

2. `ValidationPolicy`
   - checks operation support, features, and modalities against `ModelProfile`

3. `ConstraintPolicy`
   - applies request-scoped option normalization and strips unsupported parameters

4. `ProtocolPolicy`
   - selects the semantic protocol for the resolved operation family

5. `TransportPolicy`
   - selects transport based on operation family, request mode, and request characteristics

6. `SessionPolicy`
   - selects session mode, continuation strategy, and fallback behavior

These can return small intermediate structs such as `%IntentDecision{}`, `%TransportDecision{}`, or `%SessionDecision{}` if that improves clarity. The rest of the system should still see one `%ExecutionPlan{}` output from the planner boundary.

## Validation and Constraint Ownership

The planner owns:

1. operation compatibility checks
2. modality checks
3. request-scoped constraint application
4. transport eligibility checks
5. session eligibility checks
6. mapping public API verbs onto canonical operation families

Transport, provider, and semantic protocol modules must not repeat these checks.

## Example: `openai:gpt-5.4`

For `openai:gpt-5.4`, the planner should distinguish between at least two cases:

1. Stateless one-shot generation
   - semantic protocol: `:openai_responses`
   - transport: `:http_sse`
   - session mode: `:none`

2. Long-running tool-heavy coding session
   - semantic protocol: `:openai_responses`
   - transport: `:websocket`
   - session mode: `:attach_or_create`
   - continuation strategy: `:previous_response_id`

The model profile says websocket is allowed. The planner says whether websocket is appropriate for this request.
