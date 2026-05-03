# ReqLlmNext

> ⚠️ **Experimental**: ReqLlmNext is still evolving quickly, but its core v2 architecture is now implemented as the working package foundation.

ReqLlmNext is a metadata-driven LLM client library for Elixir. The goal is to support a wide range of provider APIs behind one canonical ReqLlm-style surface, without letting one model's quirks leak into the rest of the system.

## Current Provider Families

ReqLlmNext currently ships:

1. Anthropic native Messages support
2. OpenAI native families for chat, Responses, realtime, embeddings, and media
3. OpenAI-compatible provider slices for DeepSeek, Groq, OpenRouter, vLLM, xAI, Venice, Alibaba, Cerebras, Z.AI, and Zenmux
4. Native new-family slices for Google Gemini generateContent plus Google embeddings and image generation, ElevenLabs media, and Cohere chat

Wrapper platforms such as Azure, Google Vertex, and Amazon Bedrock remain intentionally deferred.

ReqLlmNext also accepts packaged `LLMDB` models outside those first-class slices on a best-effort basis when `LLMDB` publishes enough typed runtime metadata to execute them safely through an existing canonical family.

## Quick Start

```elixir
{:ok, response} = ReqLlmNext.generate_text("openai:gpt-4o-mini", "Hello!")
ReqLlmNext.Response.text(response)

{:ok, stream_resp} =
  ReqLlmNext.stream_text("anthropic:claude-sonnet-4-20250514", "Tell me a story")

stream_resp.stream |> Enum.each(&IO.write/1)

schema = [name: [type: :string, required: true], age: [type: :integer]]
{:ok, resp} = ReqLlmNext.generate_object("openai:gpt-4o-mini", "Generate a person", schema)
resp.object

{:ok, image_resp} = ReqLlmNext.generate_image("openai:gpt-image-1", "A paper kite over a lake")
ReqLlmNext.Response.image_data(image_resp)

{:ok, transcript} = ReqLlmNext.transcribe("openai:gpt-4o-transcribe", "/tmp/audio.mp3")
transcript.text

{:ok, speech} = ReqLlmNext.speak("openai:gpt-4o-mini-tts", "Hello from ReqLlmNext")
speech.audio

ReqLlmNext.support_status("openai:gpt-4o-mini")
#=> :first_class

ReqLlmNext.support_status("mistral:pixtral-large-latest")
#=> :best_effort
```

## Support Tiers

ReqLlmNext now exposes three support tiers through `support_status/1`:

1. `:first_class`
   - the provider has a dedicated slice with provider-owned validation, utilities, and deeper proof
2. `:best_effort`
   - the model is packaged in `LLMDB` and can execute safely through typed `LLMDB.Provider.runtime` and `LLMDB.Model.execution` metadata using an existing canonical family
3. `{:unsupported, reason}`
   - the model is catalog-only, missing required runtime metadata, or names an execution family ReqLlmNext does not know how to run

Best-effort support is intentionally narrower than first-class support:

1. it covers canonical operations such as text, object, embeddings, media, and realtime only when `LLMDB` declares them
2. it does not imply provider-native utility endpoints
3. it fails fast when required runtime configuration such as account-scoped base URL variables is missing

## Credential Modes

ReqLlmNext has two credential modes:

1. standalone mode
   - local application code may pass `:api_key` or provider-specific options directly, and provider modules may read local environment variables such as `OPENAI_API_KEY` or `ANTHROPIC_API_KEY`
   - `.env` loading exists only for local development, replay, and opt-in live verification ergonomics
2. governed mode
   - callers pass `:governed_authority` with an externally issued `ReqLlmNext.GovernedAuthority`
   - provider keys, base URLs, direct URLs, headers, realtime tokens, account ids, model-account ids, organization ids, project ids, and runtime metadata env credential fallbacks are rejected as unmanaged request authority
   - canonical HTTP, streaming, OpenAI Responses WebSocket, OpenAI realtime, media, embedding, runtime-metadata, and provider-owned utility requests take their base URL, headers, query, and template values from the governed authority
   - fixture capture and replay redact governed credential headers the same way they redact standalone provider credentials

Standalone env behavior is not a governance path. Governed callers must provide authority through the explicit contract and must not rely on machine environment state.

## Architecture

<!-- covers: reqllm.architecture.model_input_boundary reqllm.architecture.facts_mode_policy_plan reqllm.architecture.execution_layers -->

ReqLlmNext is built around a small runtime model:

```text
Model Source
  -> Model Profile
  -> Execution Mode
  -> Policy Rules
  -> Execution Plan
  -> Deterministic Execution Stack
```

The core rules are:

1. model input is either an `LLMDB` `model_spec` string or a handcrafted `%LLMDB.Model{}`
2. string model resolution stays delegated to `LLMDB`
3. `ModelProfile` describes facts, `ExecutionMode` describes intent, and `ExecutionPlan` is the only prescriptive runtime object
4. one resolved plan selects one deterministic stack of provider, session runtime, semantic protocol, wire format, transport, and plan adapters
5. results are normalized back to the canonical ReqLlm API surface, including `Response`, `StreamResponse`, `ReqLlmNext.Transcription.Result`, and `ReqLlmNext.Speech.Result`
6. canonical output items sit underneath `Response` and `StreamResponse`, and explicit result channels for message, reasoning, tools, media, annotations, refusals, and provider-native extras stay faithful before helper methods collapse them into simpler shapes

Concrete provider and family implementation code is co-located in vertical slice homes under `lib/req_llm_next/families/` and `lib/req_llm_next/providers/`, while shared contracts and planning code stay central.

ReqLlmNext also now owns:

1. `ReqLlmNext.Telemetry` as the stable runtime telemetry kernel
2. `ReqLlmNext.Realtime` as a transport-agnostic realtime core with provider adapters and canonical session reduction

For the covered Wave 3 minimal lane, unary request/response execution now
compiles into `HttpExecutionIntent.v1` and delegates the lower HTTP hop through
`execution_plane` via an internal execution-plane HTTP adapter. Provider planning,
fixture replay, telemetry, response normalization, and the package-owned
realtime core remain in `reqllm_next`. Wave 6 now also moves the lower SSE and
WebSocket stream lifecycle onto `execution_plane`, while provider semantics,
wire decoding, and realtime session reduction stay local to `reqllm_next`.

## Package Thesis

ReqLlmNext is agent-assisted, but it is not agent-governed.

The source of truth is the architecture plus the verification loop:

1. long-form architecture docs and ADRs define the intended boundaries
2. checked `.spec/` subjects keep the current truth small and enforceable
3. scenario tests exercise the canonical public API instead of isolated provider branches
4. fixture replay and live compatibility runs verify normalization against real APIs
5. agents accelerate implementation, but correctness is established by those constraints rather than by model output alone

The longer explanation lives in [`guides/package_thesis.md`](./guides/package_thesis.md).

## Documentation

Start with:

1. [`guides/package_thesis.md`](./guides/package_thesis.md) for the package thesis
2. [`guides/provider_expansion_roadmap.md`](./guides/provider_expansion_roadmap.md) for the current provider-family inventory and deferred queue
3. [`guides/openai_surface_map.md`](./guides/openai_surface_map.md) for the current OpenAI coverage boundary
4. [`guides/anthropic_surface_map.md`](./guides/anthropic_surface_map.md) for the current Anthropic coverage boundary
5. [`guides/google_surface_map.md`](./guides/google_surface_map.md) for the current Google coverage boundary
6. `.spec/README.md` for the canonical Spec Led workspace
7. `.spec/specs/architecture.spec.md` for the runtime architecture contract
8. `.spec/specs/package.spec.md` for the package runtime and verification contract

## Contributor Workflow

<!-- covers: reqllm.workflow.beadwork_primed reqllm.workflow.specled_loop -->

This repository keeps two complementary systems:

- `bw` (Beadwork) for durable work tracking across sessions and hand-offs
- `.spec/` for the canonical architecture, package contracts, ADRs, and Spec Led checks validated by `mix spec.*`

ReqLlmNext currently targets Elixir `~> 1.19`.

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

For the current starter slice, use replay-backed verification by default:

```bash
mix test.starter_slice
```

When live API keys are available and you want to refresh fixtures for that slice:

```bash
REQ_LLM_NEXT_FIXTURES_MODE=record mix test.starter_slice
```

Sparse live verifier tests exist for Anthropic and OpenAI drift checks, but they are intentionally separate from the replay-backed default suite and should not be treated as normal CI coverage:

```bash
REQ_LLM_NEXT_RUN_LIVE_VERIFIERS=1 mix test.live_verifiers
```

The broader provider expansion wave is currently verified through replay-backed provider-slice tests and focused unit or wire suites rather than by broad live matrices.

Best-effort packaged provider coverage now also includes a curated replay-backed proof matrix for representative non-first-class providers such as Mistral, TogetherAI, GitHub Models, Perplexity, and Cloudflare Workers AI.
