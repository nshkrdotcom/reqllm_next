# Provider Spec

Status: Proposed

<!-- covers: reqllm.layer_boundaries.separated_io -->

## Objective

Define the provider boundary so auth and endpoint policy remain separate from protocol, wire-format, and transport behavior.

## Purpose

A provider represents infrastructure and authentication policy for a service such as OpenAI or Anthropic.

## Responsibilities

1. Define provider identity.
2. Resolve API keys and auth strategy.
3. Supply provider headers.
4. Supply endpoint roots by transport family.
5. Supply provider-level timeout and rate-limit hints if needed.

## Canonical Output Shape

```elixir
%ProviderContext{
  provider: :openai,
  auth: %{style: :bearer, api_key: "..."},
  endpoint_roots: %{
    http: "https://api.openai.com",
    websocket: "wss://api.openai.com"
  },
  headers: %{
    "OpenAI-Beta" => "..."
  }
}
```

## Invariants

1. Provider does not choose model-specific behavior.
2. Provider does not encode request payloads.
3. Provider does not decode event payloads.
4. Provider does not manage session continuation ids.

## Route Ownership Rule

To avoid ambiguous URL ownership:

1. Provider owns endpoint roots.
2. Wire format owns relative routes, event targets, and content-type expectations.
3. Transport composes the two.

This prevents duplicated path ownership such as `/v1` being embedded in both provider and wire-format layers.

## Example: OpenAI

For OpenAI:

1. Provider owns auth via bearer token.
2. Provider owns roots such as `https://api.openai.com` and `wss://api.openai.com`.
3. Wire format decides whether the route is `/v1/responses`, `/v1/chat/completions`, or another provider-facing target.

## Example: `openai:gpt-5.4`

`gpt-5.4` does not change provider behavior. It still uses the OpenAI provider.

The provider should not need special code for:

1. reasoning models
2. websocket responses mode
3. tool-heavy sessions

Those belong to profile, planning, session, protocol, or wire-format layers.
