defmodule ReqLlmNext.SupportMatrix do
  @moduledoc """
  Curated scenario-backed provider/model coverage matrix for pressure-testing the execution-plan architecture.

  The support matrix is intentionally not the whole coverage story.

  It covers cross-provider scenario lanes that should remain cost-aware, replayable,
  and stable enough to run as the package's broader compatibility sweep.

  Provider-native surfaces that do not fit the generic scenario system belong in
  focused `test/provider_features/` coverage instead of being forced into this matrix.

  Sparse opt-in live verifier tests belong in `test/live_verifiers/` rather than
  expanding this replay-first matrix into a live provider sweep.

  The support matrix intentionally stays anchored on Anthropic and OpenAI model
  lanes even as broader provider expansion lands through replay-backed provider-slice
  tests for Groq, OpenRouter, vLLM, xAI, Venice, Alibaba, Cerebras, Z.AI,
  Zenmux, Google Gemini, ElevenLabs, and Cohere.
  """

  @type group :: :coverage | :websocket

  @type entry :: %{
          id: atom(),
          spec: String.t(),
          provider: atom(),
          lane: atom(),
          group: group(),
          scenarios: [atom()],
          opts: keyword()
        }

  @entries [
    %{
      id: :anthropic_haiku_45,
      spec: "anthropic:claude-haiku-4-5",
      provider: :anthropic,
      lane: :baseline,
      group: :coverage,
      scenarios: [
        :basic,
        :streaming,
        :usage,
        :token_limit,
        :multi_turn,
        :object_streaming,
        :tool_multi,
        :tool_round_trip,
        :tool_none,
        :reasoning,
        :image_input,
        :prompt_caching
      ],
      opts: []
    },
    %{
      id: :anthropic_sonnet_46,
      spec: "anthropic:claude-sonnet-4-6",
      provider: :anthropic,
      lane: :high_context,
      group: :coverage,
      scenarios: [:basic, :streaming, :multi_turn, :object_streaming, :reasoning, :image_input],
      opts: []
    },
    %{
      id: :anthropic_opus_46,
      spec: "anthropic:claude-opus-4-6",
      provider: :anthropic,
      lane: :max_capability,
      group: :coverage,
      scenarios: [:basic, :streaming, :reasoning],
      opts: []
    },
    %{
      id: :openai_gpt_4o_mini,
      spec: "openai:gpt-4o-mini",
      provider: :openai,
      lane: :baseline,
      group: :coverage,
      scenarios: [
        :basic,
        :streaming,
        :usage,
        :token_limit,
        :multi_turn,
        :object_streaming,
        :tool_multi,
        :tool_round_trip,
        :tool_none,
        :image_input
      ],
      opts: []
    },
    %{
      id: :openai_gpt_41_mini,
      spec: "openai:gpt-4.1-mini",
      provider: :openai,
      lane: :high_context,
      group: :coverage,
      scenarios: [:basic, :streaming, :multi_turn, :tool_multi, :tool_round_trip, :tool_none],
      opts: []
    },
    %{
      id: :openai_o4_mini,
      spec: "openai:o4-mini",
      provider: :openai,
      lane: :reasoning,
      group: :coverage,
      scenarios: [
        :basic,
        :streaming,
        :multi_turn,
        :reasoning,
        :tool_multi,
        :tool_none
      ],
      opts: [reasoning_effort: :low, max_tokens: 600]
    },
    %{
      id: :openai_gpt_4o_mini_websocket,
      spec: "openai:gpt-4o-mini",
      provider: :openai,
      lane: :baseline,
      group: :websocket,
      scenarios: [:basic, :object_streaming, :tool_multi],
      opts: [transport: :websocket, fixture_suffix: "websocket"]
    },
    %{
      id: :openai_gpt_41_mini_websocket,
      spec: "openai:gpt-4.1-mini",
      provider: :openai,
      lane: :high_context,
      group: :websocket,
      scenarios: [:basic],
      opts: [transport: :websocket, fixture_suffix: "websocket"]
    },
    %{
      id: :openai_o4_mini_websocket,
      spec: "openai:o4-mini",
      provider: :openai,
      lane: :reasoning,
      group: :websocket,
      scenarios: [:basic, :reasoning],
      opts: [
        transport: :websocket,
        fixture_suffix: "websocket",
        reasoning_effort: :low,
        max_tokens: 600
      ]
    }
  ]

  @spec entries() :: [entry()]
  def entries, do: @entries

  @spec entries(atom(), group()) :: [entry()]
  def entries(provider, group) when is_atom(provider) and group in [:coverage, :websocket] do
    Enum.filter(@entries, &(&1.provider == provider and &1.group == group))
  end

  @spec entry!(atom()) :: entry()
  def entry!(id) when is_atom(id) do
    Enum.find(@entries, &(&1.id == id)) ||
      raise ArgumentError, "unknown support matrix entry: #{inspect(id)}"
  end
end
