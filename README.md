# ReqLlmNext

> ⚠️ **Experimental**: This is an architectural spike for ReqLLM v2. It explores a metadata-driven approach where adding new models requires only LLMDB updates, not code changes.

ReqLlmNext is a metadata-driven LLM client library for Elixir. It provides a unified interface for working with multiple LLM providers (OpenAI, Anthropic, etc.) through a clean boundary-driven architecture.

## Quick Start

```elixir
# Text generation
{:ok, response} = ReqLlmNext.generate_text("openai:gpt-4o-mini", "Hello!")
ReqLlmNext.Response.text(response)

# Streaming
{:ok, stream_resp} = ReqLlmNext.stream_text("anthropic:claude-sonnet-4-20250514", "Tell me a story")
stream_resp.stream |> Enum.each(&IO.write/1)

# Structured output
schema = [name: [type: :string, required: true], age: [type: :integer]]
{:ok, resp} = ReqLlmNext.generate_object("openai:gpt-4o-mini", "Generate a person", schema)
resp.object #=> %{"name" => "Alice", "age" => 30}

# Embeddings
{:ok, embedding} = ReqLlmNext.embed("openai:text-embedding-3-small", "Hello world")
```

## Architecture

<!-- covers: reqllm.architecture.model_input_boundary reqllm.architecture.facts_mode_policy_plan reqllm.architecture.execution_layers -->

ReqLlmNext is moving toward a **boundary-driven architecture** that separates model normalization, planning, protocol semantics, wire format, transport, and provider concerns:

```
Public API
  -> Model Input Boundary
  -> Model Profile
  -> Execution Mode
  -> Policy Rules
  -> Execution Plan
  -> Operation Planner
  -> Semantic Protocol
  -> Wire Format
  -> Session Runtime
  -> Transport
  -> Provider

Execution surfaces are the stable support unit for endpoint styles.
Policy rules and plan-aware adapters shape execution without collapsing layers together.
```

The current codebase still reflects an earlier spike architecture in places. The specs in `specs/` define the target refactor boundary model.

## Specs

Architecture and override specifications live in [`specs/`](./specs):

- [`specs/README.md`](./specs/README.md) - Spec index
- [`specs/project_summary.md`](./specs/project_summary.md) - High-level project summary
- [`specs/architecture.md`](./specs/architecture.md) - Overall architecture
- [`specs/enforcement.md`](./specs/enforcement.md) - Runtime hard-fail boundary and CI guardrails
- [`specs/layer_boundaries.md`](./specs/layer_boundaries.md) - Cross-layer handoff rules
- [`specs/model_source.md`](./specs/model_source.md) - Public model-spec input boundary
- [`specs/model_profile.md`](./specs/model_profile.md) - Descriptive model profile and surface catalog
- [`specs/execution_mode.md`](./specs/execution_mode.md) - Normalized request mode
- [`specs/execution_surface.md`](./specs/execution_surface.md) - Endpoint-style support unit
- [`specs/overrides.md`](./specs/overrides.md) - Policy rules and plan-aware adapters
- [`specs/execution_plan.md`](./specs/execution_plan.md) - Fully resolved execution behavior
- [`specs/operation_planner.md`](./specs/operation_planner.md) - Planner assembly boundary
- [`specs/semantic_protocol.md`](./specs/semantic_protocol.md) - Protocol semantics
- [`specs/wire_format.md`](./specs/wire_format.md) - Wire envelopes and framing contract
- [`specs/session_runtime.md`](./specs/session_runtime.md) - Persistent session state
- [`specs/transport.md`](./specs/transport.md) - Transport contract
- [`specs/provider.md`](./specs/provider.md) - Provider boundary

## Contributor Workflow

<!-- covers: reqllm.workflow.beadwork_primed reqllm.workflow.specled_loop -->

This repository now keeps two complementary kinds of project truth:

- `bw` (Beadwork) for durable work tracking across sessions and agent hand-offs
- `.spec/` for current-truth package and workflow contracts validated by `mix spec.*`

The existing [`specs/`](./specs) directory remains the long-form architecture and refactor reference. The new [`.spec/`](./.spec) workspace is the smaller checked contract that drives the Spec Led Development loop.
ReqLlmNext itself currently targets Elixir `~> 1.19`.

Start a working session with:

```bash
bw prime
mix spec.prime --base HEAD
```

Then use the default loop:

```bash
mix spec.next
mix spec.check --base HEAD
```

## Current Direction

The current design direction is:

1. Public APIs accept only two model input forms:
   - registry strings
   - `%LLMDB.Model{}`
2. That input is normalized at a strict runtime boundary.
3. `ModelProfile` is descriptive only and declares named `ExecutionSurface`s instead of implying a free mix of protocol, wire format, and transport choices.
4. Public request intent is normalized into `%ExecutionMode{}` before policy resolution.
5. Ordered policy rules match across provider, family, model, operation, and mode scopes to choose surfaces, defaults, and fallbacks.
6. `%ExecutionPlan{}` is the only prescriptive runtime object consumed by downstream execution layers.
7. Semantic protocol, wire format, transport, and provider remain separate so one API family can run over multiple endpoint styles without fusing meaning, envelopes, and byte movement.
8. Session runtime is first-class for continuation-based APIs such as OpenAI Responses over WebSocket.
9. Adapters are a narrow escape hatch and the target architecture treats them as plan-aware, layer-scoped patches rather than a global raw-model mutation pipeline.

The sections below describe the current spike implementation, not the final target architecture. In the current code, `ReqLlmNext.Wire.*` modules still combine semantic protocol and wire-format duties that the 2.0 architecture now treats as separate layers.

### Current Spike Layer 1: `Wire.*` Modules

The current `Wire.*` modules handle **request/response mapping plus provider-family envelopes** between ReqLlmNext types and provider JSON formats. In the 2.0 target, this responsibility splits into:

- semantic protocol for API-family meaning and canonical event decoding
- wire format for transport-facing routes, headers, envelopes, and framing shapes

```elixir
# Behaviour: ReqLlmNext.Wire.Streaming
@callback endpoint() :: String.t()
@callback encode_body(LLMDB.Model.t(), String.t(), keyword()) :: map()
@callback decode_sse_event(sse_event(), LLMDB.Model.t()) :: [String.t() | nil]
@callback headers(keyword()) :: [{String.t(), String.t()}]  # optional
```

Current wire implementations:
- `Wire.OpenAIChat` — Standard `/v1/chat/completions` format
- `Wire.OpenAIResponses` — Reasoning models `/v1/responses` format
- `Wire.OpenAIEmbeddings` — `/v1/embeddings` format
- `Wire.Anthropic` — `/v1/messages` with thinking support

### Current Spike Layer 2: Providers

Providers handle **HTTP configuration only**—base URLs, authentication headers, API keys.

```elixir
# Minimal provider definition using the macro
defmodule ReqLlmNext.Providers.OpenAI do
  use ReqLlmNext.Provider,
    base_url: "https://api.openai.com",
    env_key: "OPENAI_API_KEY",
    auth_style: :bearer
end
```

### Current Spike Layer 3: Model Adapters (Optional)

Adapters handle **per-model customizations** for the ~5% of models that need special handling beyond what LLMDB metadata can express.

```elixir
# Behaviour: ReqLlmNext.ModelAdapter
@callback matches?(LLMDB.Model.t()) :: boolean()
@callback transform_opts(LLMDB.Model.t(), keyword()) :: keyword()
```

Examples: reasoning model defaults, extended thinking mode, model-specific parameter tweaks.

## LLMDB Integration

ReqLlmNext is built on [LLMDB](https://github.com/your-org/llmdb), a comprehensive database of LLM metadata. LLMDB provides:

- Model capabilities (chat, tools, streaming, JSON output, etc.)
- Wire protocol selection based on model metadata
- Parameter constraints (token limits, temperature ranges, etc.)
- Provider configuration

The long-term goal is that production model support should usually require only LLMDB updates while the public runtime boundary stays narrow and predictable.

### Model Resolution

```elixir
# Models are resolved via LLMDB
{:ok, model} = ReqLlmNext.model("openai:gpt-4o-mini")

# Current spike metadata access
model.capabilities      #=> %{chat: true, tools: %{enabled: true}, ...}
model.extra.wire        #=> %{protocol: "openai_chat"}
model.extra.constraints #=> %{...}
```

The target architecture moves this raw metadata access behind the model input boundary and `%ModelProfile{}` normalization.

### Model Overrides

You can override LLMDB defaults at runtime via application config:

```elixir
# config/config.exs
config :req_llm_next, :model_overrides, %{
  "openai:gpt-4o-mini" => %{
    extra: %{
      constraints: %{
        max_tokens: %{default: 4096}
      }
    }
  }
}
```

Or per-request:

```elixir
ReqLlmNext.generate_text("openai:gpt-4o-mini", "Hello", 
  max_tokens: 500,
  temperature: 0.7
)
```

## Scenario & Fixture System

ReqLlmNext uses a **scenario-based testing system** that validates model capabilities through the public API.

### Scenarios

Scenarios are modules that test specific capabilities:

```elixir
defmodule ReqLlmNext.Scenarios.Basic do
  use ReqLlmNext.Scenario,
    id: :basic,
    name: "Basic Text",
    description: "Pipeline works at all for chat models"

  @impl true
  def applies?(%LLMDB.Model{} = model) do
    get_in(model.capabilities, [:chat]) == true
  end

  @impl true
  def run(model_spec, _model, opts) do
    case ReqLlmNext.generate_text(model_spec, "Hello!", opts) do
      {:ok, resp} -> ok([step("call", :ok, response: resp)])
      {:error, reason} -> error(reason)
    end
  end
end
```

Available scenarios:
- `:basic` — Pipeline works for chat models
- `:streaming` — SSE streaming works correctly
- `:usage` — Token usage metrics returned
- `:tool_multi` — Model selects correct tool
- `:tool_round_trip` — Full tool execution loop
- `:object_basic` — Structured JSON output
- `:reasoning` — Thinking/reasoning tokens
- `:embedding` — Vector embeddings

### Fixture Replay System

Tests run against recorded fixtures by default, enabling fast, deterministic CI without API calls:

```bash
# Run tests using recorded fixtures (default)
mix test

# Record new fixtures (makes live API calls)
REQ_LLM_NEXT_FIXTURES_MODE=record mix test
```

Fixtures capture raw SSE chunks at the Finch level:

```
test/fixtures/
├── openai/
│   ├── gpt_4o_mini/
│   │   ├── basic.json
│   │   ├── streaming.json
│   │   └── tool_round_trip_1.json
│   └── ...
└── anthropic/
    └── claude_sonnet_4_20250514/
        ├── basic.json
        └── reasoning.json
```

Fixture format:
```json
{
  "provider": "openai",
  "model_id": "gpt-4o-mini",
  "prompt": "Hello!",
  "request": { "method": "POST", "url": "...", "headers": {...}, "body": {...} },
  "response": { "status": 200, "headers": {...} },
  "chunks": ["base64-encoded-sse-chunk", ...]
}
```

### Using Fixtures in Scenarios

```elixir
def run(model_spec, _model, opts) do
  # The fixture name is derived from the scenario id
  call_opts = Keyword.merge(opts, fixture: fixture_name(id()))
  
  ReqLlmNext.generate_text(model_spec, "Hello!", call_opts)
end
```

For multi-step scenarios:
```elixir
# Step 1 uses fixture "tool_round_trip_1"
call_opts = Keyword.merge(opts, fixture: fixture_name(id(), "1"))

# Step 2 uses fixture "tool_round_trip_2"
call_opts = Keyword.merge(opts, fixture: fixture_name(id(), "2"))
```

## Configuration

### API Keys

Keys are loaded in order of precedence:

1. Per-request `:api_key` option
2. Application config: `config :req_llm_next, :openai_api_key, "..."`
3. System environment: `OPENAI_API_KEY`

### Environment Variables

- `OPENAI_API_KEY` — OpenAI API key
- `ANTHROPIC_API_KEY` — Anthropic API key
- `REQ_LLM_NEXT_FIXTURES_MODE` — `record` or `replay` (default: replay)

## Development

```bash
cd req_llm_next

# Run tests
mix test

# Record fixtures (live API calls)
REQ_LLM_NEXT_FIXTURES_MODE=record mix test

# Format and compile
mix format && mix compile
```

## Design Goals

1. **LLMDB is the single source of truth** — Model capabilities, protocol defaults, wire-format compatibility, and constraints flow from metadata
2. **Adding models should require metadata only** — Ideally zero code changes for new models
3. **Boundary-driven separation** — Semantic protocol, wire format, transport, provider, and adapters have distinct jobs
4. **Streaming-first** — All operations internally use streaming; non-streaming calls buffer
5. **Fixture-based testing** — Fast, deterministic CI without live API calls

## Comparison to req_llm (v1)

| Aspect | req_llm (v1) | ReqLlmNext (v2) |
|--------|--------------|-----------------|
| Model support | ~125 models with code | 2000+ models via LLMDB |
| Adding models | 2-4 hours (code changes) | 5-15 minutes (metadata) |
| Model heuristics | 15+ pattern matches | 0 (metadata-driven) |
| Provider code | ~2000+ lines each | ~200 lines each |
| Test approach | Live + cached | Fixture replay |
