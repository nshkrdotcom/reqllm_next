# Transport Spec

Status: Proposed

## Objective

Define the contract for moving protocol payloads over HTTP, SSE, or WebSocket without changing semantic behavior.

## Purpose

Transport owns connection mechanics. It does not own provider semantics.

## Supported Modes

1. `:http`
2. `:http_sse`
3. `:websocket`

Additional modes may be added later if they preserve the same contract.

## Responsibilities

1. Open connections when needed.
2. Apply provider auth and provider headers.
3. Apply framing for the selected transport.
4. Send outbound protocol payloads.
5. Receive inbound frames or responses.
6. Surface transport-level failures.

## Inputs

1. `ExecutionPlan`
2. Provider endpoint root and auth data
3. Protocol route or event target
4. Optional session handle

## Outputs

1. Raw inbound provider events or payload maps
2. Transport lifecycle signals
3. Structured transport errors

## Canonical Interface

```elixir
@callback transport_id() :: atom()
@callback execute(ExecutionPlan.t(), ProviderContext.t(), payload :: map(), session :: term()) ::
  {:ok, Enumerable.t() | term()} | {:error, term()}
```

## Invariants

1. Transport must not inspect model names.
2. Transport must not mutate semantic request structure.
3. Transport must not decode semantic event meaning.
4. Transport must emit structured failures for connect, timeout, framing, and disconnect problems.

## WebSocket Requirements

For WebSocket mode:

1. The transport owns the socket lifecycle.
2. The transport owns connect and close.
3. The transport owns keepalive and reconnect.
4. The transport must support request/response correlation if the protocol requires it.
5. The transport must respect protocol-level in-flight limits.

## Example: `openai:gpt-5.4`

For `openai:gpt-5.4` on Responses WebSocket mode:

1. Transport connects to the provider websocket endpoint root.
2. Transport sends a websocket client event containing the protocol payload.
3. Transport receives websocket messages and passes parsed payload maps upstream.
4. Transport does not interpret `previous_response_id`, tool calls, or finish reasons.

## Fixture Impact

SSE fixtures are not sufficient for websocket mode.

WebSocket transport fixtures must capture:

1. outbound client events
2. inbound server events
3. connection lifecycle markers
