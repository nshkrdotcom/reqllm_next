# ReqLlmNext

> ⚠️ **Experimental**: This is the architecture spike for ReqLLM v2.

ReqLlmNext is a metadata-driven LLM client library for Elixir. The goal is to support a wide range of provider APIs behind one canonical ReqLlm-style surface, without letting one model's quirks leak into the rest of the system.

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
```

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
5. results are normalized back to the canonical ReqLlm API surface

The implementation still contains spike code in places, especially around the current `wire` and adapter paths. The architecture docs define the target boundary model the code is being reconciled toward.

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
2. `.spec/README.md` for the canonical Spec Led workspace
3. `.spec/specs/architecture.spec.md` for the runtime architecture contract
4. `.spec/specs/package.spec.md` for the package runtime and verification contract

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
