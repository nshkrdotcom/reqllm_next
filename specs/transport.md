# Transport Spec

Status: Proposed

<!-- covers: reqllm.layer_boundaries.separated_io -->

## Objective

Define the contract for moving wire-formatted requests and frames over HTTP, SSE, or WebSocket without changing semantic behavior.

## Purpose

Transport owns connection mechanics and frame movement. It does not own provider semantics or wire envelopes.

## Supported Modes

1. `:http`
2. `:http_sse`
3. `:websocket`

Additional modes may be added later if they preserve the same contract.

## Responsibilities

1. Open connections when needed.
2. Apply provider auth and provider headers.
3. Send outbound wire-formatted requests or client events.
4. Receive inbound frames or responses.
6. Surface transport-level failures.
7. Emit structured lifecycle diagnostics for compat tooling.

## Inputs

1. `ExecutionPlan`
2. Provider endpoint root and auth data
3. Wire-format route or event target
4. Optional session handle

## Outputs

1. Raw inbound transport frames or response bodies
2. Transport lifecycle signals
3. Structured transport errors

## Canonical Interface

```elixir
@callback transport_id() :: atom()
@callback execute(ExecutionPlan.t(), ProviderContext.t(), request :: term(), session :: term()) ::
  {:ok, Enumerable.t() | term()} | {:error, term()}
```

## Invariants

1. Transport must not inspect model names.
2. Transport must not mutate wire-format request structure.
3. Transport must not decode wire-format envelopes into semantic meaning.
4. Transport must emit structured failures for connect, timeout, framing, and disconnect problems.
5. Transport diagnostics must distinguish lifecycle problems from semantic protocol problems.

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
2. Transport sends a websocket text frame containing the wire-format client event.
3. Transport receives websocket messages and passes raw frames upstream.
4. Transport does not interpret `previous_response_id`, tool calls, event names, or finish reasons.

## Fixture Impact

SSE fixtures are not sufficient for websocket mode.

WebSocket transport fixtures must capture:

1. outbound client events
2. inbound server events
3. connection lifecycle markers
