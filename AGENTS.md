# AGENTS.md - ReqLlmNext v2

**IMPORTANT: DO NOT WRITE COMMENTS INTO THE BODY OF ANY FUNCTIONS.**

## Work Management

<!-- covers: reqllm.workflow.agent_instructions -->

This repository tracks durable work with `bw` (Beadwork).

- Start every session with `bw prime`.
- Treat `bw` as the durable record for tickets, progress, and decisions that must survive session boundaries.
- This repo uses the `reqllm-XYZ` issue prefix.
- If `bw prime` reports uncommitted changes, assume they may belong to the user unless you can prove otherwise.

## Spec Led Workflow

- After `bw prime`, run `mix spec.prime --base HEAD` before editing current-truth package guidance.
- Keep `.spec/` as the canonical checked workflow layer for package and contributor contracts.
- Keep the existing `specs/` directory as supporting architecture and refactor context.
- After code, docs, or tests change, run `mix spec.next`.
- When the branch is ready, run `mix spec.check --base HEAD`.

## Package Overview

`ReqLlmNext` is a metadata-driven LLM client library for Elixir. The 2.0 direction is that public runtime entrypoints accept only a registry model spec string or an `%LLMDB.Model{}`. Adding new models should, ideally, require **only metadata updates in LLMDB**, not code changes. The small set of models that still need code changes are handled by the `adapters` layer.

## Core Design Principles

1. **LLMDB is the preferred source of truth** - Model capabilities, limits, defaults, and surface facts flow from LLMDB metadata
2. **Narrow public model boundary** - Public runtime calls accept only registry strings and `%LLMDB.Model{}`
3. **Facts, mode, policy, and plan are separate** - `ModelProfile` is descriptive, `ExecutionMode` is request intent, policy rules resolve behavior, and `ExecutionPlan` is the only prescriptive object
4. **Execution surfaces are the support unit** - Endpoint styles are declared as named surfaces, not inferred from free combinations of protocol, wire format, and transport
5. **Separated execution layers** - Semantic protocol, wire format, transport, provider, session runtime, and adapters own different concerns
6. **Scenarios as capability tests** - Model-agnostic test scenarios validate capabilities through the public API
7. **Streaming-first** - All operations internally use streaming; non-streaming calls buffer the stream

## Quick Start

```bash
# Run tests (uses fixture replay by default)
mix test

# Record new fixtures (live API calls)
REQ_LLM_NEXT_FIXTURES_MODE=record mix test

# Run specific scenario tests
mix test test/scenarios/

# Format and compile
mix format && mix compile
```

## Architecture

<!-- covers: reqllm.architecture.model_input_boundary reqllm.architecture.facts_mode_policy_plan reqllm.architecture.execution_layers reqllm.layer_boundaries.plan_aware_adapters -->

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
```

The current implementation still collapses semantic protocol and wire format concerns inside `lib/req_llm_next/wire/`, and it still uses a raw-model adapter pipeline. Treat those as spike code, not the final 2.0 layer boundary.

## Module Structure

```
lib/req_llm_next/
├── req_llm_next.ex              # Public API facade
├── executor.ex                   # Central pipeline orchestration
├── model_resolver.ex             # LLMDB + config overlays
│
├── validation.ex                 # Modality & operation checks
├── constraints.ex                # Parameter transforms from metadata
│
├── adapters/
│   ├── model_adapter.ex          # Behaviour definition
│   ├── pipeline.ex               # Adapter chain execution
│   ├── openai/
│   │   ├── reasoning.ex          # o-series, GPT-5 (Responses API)
│   │   └── gpt4o_mini.ex         # Model-specific defaults
│   └── anthropic/
│       └── thinking.ex           # Extended thinking mode
│
├── wire/
│   ├── streaming.ex              # Current spike wire behaviour
│   ├── resolver.ex               # Current spike wire selection from metadata
│   ├── openai_chat.ex            # /v1/chat/completions
│   ├── openai_responses.ex       # /v1/responses (reasoning)
│   ├── openai_embeddings.ex      # /v1/embeddings
│   └── anthropic.ex              # /v1/messages
│
├── providers/
│   ├── provider.ex               # Behaviour (base_url, auth)
│   ├── openai.ex                 # OpenAI config
│   └── anthropic.ex              # Anthropic config
│
├── scenarios/                    # Capability test scenarios
│   ├── basic.ex                  # Basic text generation
│   ├── streaming.ex              # SSE streaming
│   ├── tool_round_trip.ex        # Full tool execution flow
│   └── ...
│
├── context.ex                    # Conversation history
├── response.ex                   # Response struct + helpers
├── stream_response.ex            # Streaming response wrapper
├── tool.ex                       # Tool definition
├── tool_call.ex                  # Tool call struct
├── schema.ex                     # JSON Schema from NimbleOptions
├── fixtures.ex                   # Fixture record/replay system
└── error.ex                      # Structured errors (Splode)
```

## Current Spike Implementation Layers

### Layer 1: `Wire.*` Modules

**Purpose**: The current spike `Wire.*` modules combine semantic protocol mapping and wire-format shaping between canonical ReqLlmNext types and provider JSON.

The 2.0 target splits this responsibility into:
- Semantic Protocol
- Wire Format

**Files**: `lib/req_llm_next/wire/*.ex`

**Behaviour** (`Wire.Streaming`):
```elixir
@callback endpoint() :: String.t()
@callback encode_body(LLMDB.Model.t(), String.t(), keyword()) :: map()
@callback decode_sse_event(sse_event(), LLMDB.Model.t()) :: [term()]
@callback headers(keyword()) :: [{String.t(), String.t()}]  # optional
```

**Decision criteria**: Add a new Wire module when:
- A provider uses a fundamentally different JSON structure
- HTTP/SSE/WebSocket envelopes differ significantly
- Different endpoint paths or content types are required in the current spike

**Current wires**:
- `Wire.OpenAIChat` - Standard OpenAI `/v1/chat/completions`
- `Wire.OpenAIResponses` - Reasoning models `/v1/responses`
- `Wire.Anthropic` - `/v1/messages` with thinking support
- `Wire.OpenAIEmbeddings` - `/v1/embeddings`

### Layer 2: Provider

**Purpose**: HTTP configuration only—base URLs, authentication headers, API keys.

**Files**: `lib/req_llm_next/providers/*.ex`

**Behaviour** (`Provider`):
```elixir
@callback base_url() :: String.t()
@callback env_key() :: String.t()
@callback auth_headers(api_key :: String.t()) :: [{String.t(), String.t()}]
```

**Decision criteria**: Add a new Provider module when:
- Different base URL
- Different authentication scheme
- Different API key environment variable

**Current providers**:
- `Providers.OpenAI` - Bearer auth, `OPENAI_API_KEY`
- `Providers.Anthropic` - x-api-key auth, `ANTHROPIC_API_KEY`

### Layer 3: Model Adapter (Optional)

**Purpose**: The current spike adapters handle per-model customizations for the small set of models that need special handling beyond what LLMDB metadata can express.

The 2.0 target moves this toward:
- ordered policy rules across provider, family, model, operation, and mode
- plan-aware, layer-scoped adapters that patch `ExecutionPlan`

**Files**: `lib/req_llm_next/adapters/**/*.ex`

**Behaviour** (`ModelAdapter`):
```elixir
@callback matches?(LLMDB.Model.t()) :: boolean()
@callback transform_opts(LLMDB.Model.t(), keyword()) :: keyword()
```

**Decision criteria**: Add an Adapter when:
- Model requires parameters that can't be expressed in constraints
- Default values differ significantly from other models
- API quirks require field renaming or injection

**Current adapters**:
- `OpenAI.Reasoning` - Higher defaults, timeout, token key normalization
- `OpenAI.GPT4oMini` - Model-specific defaults
- `Anthropic.Thinking` - Extended thinking mode adjustments

## Constraints vs Adapters

**Constraints** (`constraints.ex`):
- Driven entirely by LLMDB `extra.constraints` metadata
- Generic parameter transformations applicable to any model
- Examples: token key renaming, temperature support, min output tokens

**Policy rules** (target v2):
- Ordered match-and-patch rules over provider, family, model, operation, and mode
- Choose preferred surfaces, fallback surfaces, timeout classes, session defaults, and plan adapter refs
- Must not invent unsupported capability

**Adapters** (`adapters/*.ex` in the current spike, plan adapters in target v2):
- Reserved for quirks metadata and policy rules cannot express cleanly
- Target shape is a plan-aware, layer-scoped adapter, not a global raw-model mutation hook
- Examples: injecting imperative defaults after plan assembly, patching a narrow provider quirk

**Rule**: If a behavior can be expressed as descriptive metadata, surface declarations, or policy rules, keep it there. Use an adapter only when the behavior truly needs imperative code.

## Scenario System

Scenarios are the single source of truth for capability validation.

**Files**: `lib/req_llm_next/scenarios/*.ex`

**Behaviour** (`Scenario`):
```elixir
@callback applies?(LLMDB.Model.t()) :: boolean()
@callback run(model_spec :: String.t(), model :: LLMDB.Model.t(), opts :: keyword()) :: result()
```

**Usage**:
```elixir
# Get scenarios for a model
scenarios = ReqLlmNext.Scenarios.for_model(model)

# Run all applicable scenarios
results = ReqLlmNext.Scenarios.run_for_model("openai:gpt-4o-mini", model, opts)
```

**Fixture naming**: `fixture_name(scenario_id, step)` generates deterministic fixture paths.

## Fixture System

Fixtures capture raw SSE chunks for replay testing.

**Mode control**: `REQ_LLM_NEXT_FIXTURES_MODE=record|replay`

**Storage**: `test/fixtures/{provider}/{model_id}/{scenario}.json`

**Format**:
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

## Adding New Models

### If model uses the existing current `wire/` module and provider:

1. Add model to LLMDB with correct metadata
2. Ensure `extra.wire.protocol` is set if not default
3. Run scenarios: `REQ_LLM_NEXT_FIXTURES_MODE=record mix test`
4. Commit fixtures

### If model needs new constraints:

1. Add constraint fields to LLMDB `extra.constraints`
2. If new constraint type, add handler to `Constraints` module

### If model needs adapter:

1. Create adapter in `lib/req_llm_next/adapters/{provider}/{name}.ex`
2. Register in `Adapters.Pipeline.@adapters`
3. Implement `matches?/1` and `transform_opts/2`

### If model needs a new current `wire/` module:

1. Create wire module implementing `Wire.Streaming` behaviour
2. Add protocol atom to `Wire.Resolver.wire_module!/1`
3. Add LLMDB metadata: `extra.wire.protocol: "new_protocol"`

### If model uses new provider:

1. Create provider module using `use ReqLlmNext.Provider`
2. Register in `Providers.@providers`

## Code Style

- Follow standard Elixir conventions, run `mix format`
- No comments in function bodies
- Use pattern matching over conditionals
- Return `{:ok, result}` / `{:error, reason}` tuples
- Use Splode for structured errors

## Key Dependencies

- **LLMDB** - Model metadata database (separate package)
- **Finch** - HTTP client for streaming
- **Jason** - JSON encoding/decoding
- **ServerSentEvents** - SSE parsing
- **Zoi** - Struct schemas
- **Splode** - Error handling

## Environment Variables

- `OPENAI_API_KEY` - OpenAI API key
- `ANTHROPIC_API_KEY` - Anthropic API key
- `REQ_LLM_NEXT_FIXTURES_MODE` - `record` or `replay` (default: replay)
