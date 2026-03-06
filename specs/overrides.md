# Overrides and Adapters Spec

Status: Proposed

## Objective

Define a single override structure for provider-level and model-level behavior so custom behavior is explicit and predictable, and define when adapters are allowed.

## Override Domains

1. Provider overrides
   - Auth/header policy
   - Endpoint root
   - Default transport by operation family
   - Default protocol by operation family
   - Timeout defaults

2. Model overrides
   - Default protocol
   - Default transport
   - Operation-family patch
   - Feature patch
   - Constraints patch
   - Adapter selection and adapter-local config
   - Per-model operational defaults such as tokens or reasoning effort

3. Adapters
   - Ordered, imperative transforms that run after declarative overrides and request options are resolved.
   - Used only when metadata and overrides cannot express the behavior cleanly.

## Canonical Config Shape

```elixir
config :req_llm_next, :overrides, %{
  providers: %{
    openai: %{
      endpoint_root: "https://api.openai.com",
      auth: %{env_key: "OPENAI_API_KEY", style: :bearer},
      defaults: %{
        transport: %{text: :http_sse, object: :http_sse, embedding: :http},
        protocol: %{text: :openai_chat, object: :openai_chat, embedding: :openai_embeddings},
        timeout_ms: 30_000
      },
      headers: %{}
    },
    anthropic: %{
      endpoint_root: "https://api.anthropic.com",
      auth: %{env_key: "ANTHROPIC_API_KEY", style: :x_api_key},
      defaults: %{
        transport: %{text: :http_sse, object: :http_sse},
        protocol: %{text: :anthropic, object: :anthropic},
        timeout_ms: 30_000
      },
      headers: %{}
    }
  },
  models: %{
    by_id: %{
      "openai:gpt-4o-mini" => %{
        defaults: %{temperature: 0.7},
        adapters: [ReqLlmNext.Adapters.OpenAI.GPT4oMini]
      },
      "openai:o3-mini" => %{
        defaults: %{
          protocol: %{text: :openai_responses, object: :openai_responses},
          max_completion_tokens: 16_000,
          receive_timeout: 300_000
        },
        adapters: [ReqLlmNext.Adapters.OpenAI.Reasoning]
      },
      "anthropic:claude-sonnet-4-20250514" => %{
        adapters: [ReqLlmNext.Adapters.Anthropic.Thinking]
      }
    },
    by_family: %{
      "gpt-5" => %{
        defaults: %{
          protocol: %{text: :openai_responses, object: :openai_responses},
          max_completion_tokens: 16_000
        }
      }
    }
  }
}
```

Unknown override keys must fail during normalization. Overrides patch canonical profile fields only. They do not create new execution concepts or add new top-level profile sections.

## Merge and Precedence Rules

1. Merge semantics
   - Maps: deep merge
   - Scalars: last writer wins
   - Lists: replace by default

2. Precedence lowest to highest
   1. Built-in provider defaults
   2. Built-in model metadata from LLMDB
   3. Provider override config
   4. Model family override
   5. Model id override
   6. Request options
   7. Adapter transforms

3. Protected keys
   - `provider`
   - `model.id`
   - `operation`

Adapters may not mutate protected keys.

## Local Model Descriptor Interaction

When the public model spec is a local model descriptor:

1. Provider overrides still apply.
2. Family and model-id overrides do not apply by default unless the local descriptor explicitly opts into them.
3. Request options still apply normally.
4. Adapters still run normally once the local descriptor has been normalized into a `ModelProfile`.

This prevents surprising environment-level overrides from mutating a local development model unless the caller asks for that behavior.

## Provider-Specific Override Guidance

1. OpenAI
   - Use chat protocol by default for standard text/object families.
   - Use responses protocol for reasoning families and models that require it.
   - Support transport policy that can switch responses operations to websocket where enabled.

2. Anthropic
   - Use the anthropic messages protocol.
   - Keep thinking and prompt-caching policy in adapter or protocol config, not provider auth logic.

## Model-Specific Override Guidance

1. Prefer constraints metadata for generic behavior:
   - token key mapping
   - min output token enforcement
   - unsupported parameter stripping

2. Use adapters only when metadata is insufficient:
   - provider-family quirks
   - reasoning defaults
   - thinking mode transformations

3. Keep model overrides declarative:
   - avoid name-based branching outside adapter match predicates
   - keep override data colocated with model id and family matchers

4. Prefer patching typed profile fields:
   - operations
   - features
   - limits
   - defaults
   - modalities
   - constraints

5. Do not patch request-mode concepts directly:
   - `stream?` belongs to planning
   - websocket preference belongs in defaults or transport policy, not as a new operation family

## Adapter Contract

1. Input
   - `ModelProfile`
   - `ExecutionPlan`

2. Output
   - Updated `ExecutionPlan`

3. Allowed changes
   - request defaults
   - request-scoped timeout changes
   - provider-family quirks
   - protocol-specific option normalization

4. Forbidden changes
   - changing model identity
   - changing provider identity
   - mutating live transport or session handles
   - introducing side effects

5. Ordering
   - adapters run in deterministic order
   - each adapter sees the previous adapter's output
   - adapters run after declarative overrides and request options are merged

## WebSocket-Specific Overrides

For responses websocket mode, model or provider overrides may set:

1. `defaults.transport.text: :websocket` or `defaults.transport.object: :websocket`
2. connection timeout and keepalive policy
3. reconnect policy and continuation strategy

This must be expressed in override config and resolved before transport selection.

## Example: `openai:gpt-5.4`

1. Family override
   - `defaults.protocol.text: :openai_responses`
   - `defaults.protocol.object: :openai_responses`
   - allowed transports include `:http_sse` and `:websocket`

2. Model override
   - reasoning defaults
   - receive-timeout defaults
   - tool policy defaults if needed

3. Planner choice
   - stateless request can use `:http_sse`
   - persistent tool-heavy request can choose `:websocket`

## Example: `openai:gpt-5.4-dev`

For a local development descriptor such as `openai:gpt-5.4-dev`:

1. The descriptor may extend `openai:gpt-5.4` and override only the experimental fields.
2. Provider overrides still apply so auth and roots stay consistent.
3. Model-id overrides for the production `openai:gpt-5.4` should not automatically bleed into the dev model.
