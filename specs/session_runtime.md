# Session Runtime Spec

Status: Proposed

## Objective

Define the contract for persistent runtime state across multi-turn and transport-persistent executions.

## Purpose

`SessionRuntime` is the owner of continuation state. It exists because some APIs are stateful across turns even when the public API still looks like repeated calls.

## Responsibilities

1. Create, attach, and close sessions.
2. Track whether a session is stateless or persistent.
3. Track continuation identifiers such as `previous_response_id`.
4. Track transport handles when transport reuse is required.
5. Enforce in-flight rules.
6. Apply fallback when continuation state is no longer valid.

## Session Types

1. `:none`
   - no session state

2. `:stateless`
   - request history supplied entirely by caller context

3. `:persistent`
   - runtime stores protocol continuation state and optionally transport handles

## Output Shape

```elixir
%SessionRuntime{
  id: "sess_123",
  provider: :openai,
  semantic_protocol: :openai_responses,
  transport: :websocket,
  status: :ready,
  in_flight?: false,
  protocol_state: %{
    previous_response_id: "resp_abc"
  },
  transport_state: %{
    socket_ref: ...
  },
  expires_at: ~U[2026-03-05 20:00:00Z]
}
```

## Invariants

1. Session state is runtime state, not model metadata.
2. Session state must not be embedded into `ModelProfile`.
3. Session state must not define protocol payloads.
4. Session state must not own provider auth rules.

## Example: `openai:gpt-5.4` on Responses WebSocket

For a tool-heavy `gpt-5.4` session:

1. Turn 1 creates a session and opens a websocket transport.
2. The semantic protocol emits a Responses payload.
3. The session stores the resulting `previous_response_id`.
4. Turn 2 sends only incremental input plus the stored continuation id.
5. If the socket expires or the provider rejects the continuation id, the session runtime chooses fallback behavior.

## Fallback Rules

A session runtime may define fallback such as:

1. reconnect websocket and continue if protocol state is still valid
2. fall back to HTTP SSE for the next turn
3. rebuild full context when continuation ids are invalid or unavailable

## What Does Not Belong Here

1. model default resolution
2. protocol payload encoding
3. provider auth headers
4. modality validation
