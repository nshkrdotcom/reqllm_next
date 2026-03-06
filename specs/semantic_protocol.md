# Semantic Protocol Spec

Status: Proposed

## Objective

Define the contract for provider API families independently from transport.

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
2. Define the protocol route key or relative path.
3. Decode provider-family events into canonical chunks.
4. Normalize protocol-specific terminal metadata such as finish reasons, usage, and continuation ids.

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
@callback route(Operation.t()) :: String.t()
@callback decode_event(term(), decode_state :: map()) :: {[canonical_chunk()], map()}
@callback extract_protocol_meta([canonical_chunk()]) :: map()
```

## Invariants

1. A semantic protocol must not own sockets, HTTP clients, or retries.
2. A semantic protocol must not know provider auth headers.
3. A semantic protocol must not decide whether execution uses SSE or WebSocket.

## Transport Separation Rule

If the same provider API family can run over both SSE and WebSocket, it is still one semantic protocol.

`openai:gpt-5.4` using Responses API is:

1. semantic protocol: `:openai_responses`
2. transport: either `:http_sse` or `:websocket`

That is not two wire modules. It is one semantic protocol over two transports.

## Example: Responses Over WebSocket

For OpenAI Responses WebSocket mode:

1. The semantic protocol builds the normal Responses request body.
2. The transport wraps it in the websocket client event envelope such as `response.create`.
3. The same semantic decoder handles server events because the API family semantics are the same.

## What Does Not Belong Here

1. `Accept: text/event-stream`
2. WebSocket connect URLs
3. reconnect policy
4. socket keepalive
5. one-in-flight enforcement
