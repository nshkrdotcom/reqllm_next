# Semantic Protocol Spec

Status: Proposed

<!-- covers: reqllm.layer_boundaries.separated_io -->

## Objective

Define the contract for provider API families independently from wire format and transport.

## Purpose

A semantic protocol describes what a provider API means. It owns canonical request mapping and canonical event decoding for one API family.

Examples:

1. `:openai_chat`
2. `:openai_responses`
3. `:anthropic_messages`
4. `:openai_embeddings`
5. `:openai_realtime`

## Responsibilities

1. Accept an `ExecutionPlan` and produce a protocol payload.
2. Decode provider-family events into canonical chunks.
3. Normalize protocol-specific terminal metadata such as finish reasons, usage, and continuation ids.
4. Emit structured protocol diagnostics so compat tooling can classify semantic anomalies.

## Input

1. `ExecutionPlan`
2. Optional protocol state from `SessionRuntime`

## Output

1. Outbound protocol payload
2. Inbound canonical chunks
3. Protocol metadata updates

## Canonical Interface

```elixir
@callback protocol_id() :: atom()
@callback operation_payload(ExecutionPlan.t()) :: map()
@callback decode_event(term(), decode_state :: map()) :: {[canonical_chunk()], map()}
@callback extract_protocol_meta([canonical_chunk()]) :: map()
```

## Invariants

1. A semantic protocol must not own sockets, HTTP clients, or retries.
2. A semantic protocol must not know provider auth headers.
3. A semantic protocol must not decide whether execution uses SSE or WebSocket.
4. A semantic protocol must not own transport routes or client-event envelopes.

## Transport Separation Rule

If the same provider API family can run over both SSE and WebSocket, it is still one semantic protocol.

`openai:gpt-5.4` using Responses API is:

1. semantic protocol: `:openai_responses`
2. wire format: `:openai_responses_http_json` or `:openai_responses_ws_json`
3. transport: either `:http_sse` or `:websocket`

That is not two semantic protocols. It is one semantic protocol over multiple wire formats and transports.

## Example: Responses Over WebSocket

For OpenAI Responses WebSocket mode:

1. The semantic protocol builds the normal Responses request body.
2. The wire format wraps it in the websocket client event envelope such as `response.create`.
3. The transport moves that client event over the socket.
4. The same semantic decoder handles server events because the API family semantics are the same.

## Compat Attribution

Protocol-layer anomalies should be attributable here, for example:

1. invalid payload semantics
2. unexpected event ordering
3. decode failures
4. missing finish reasons or usage metadata

## What Does Not Belong Here

1. `Accept: text/event-stream`
2. `/v1/responses` or websocket event targets
3. WebSocket connect URLs
4. reconnect policy
5. socket keepalive
6. one-in-flight enforcement
