defmodule ReqLlmNext.Wire.ZenmuxChat do
  @moduledoc """
  Zenmux chat-completions wire built on the OpenAI-compatible happy path.
  """

  @behaviour ReqLlmNext.Wire.Streaming

  alias ReqLlmNext.SemanticProtocols.ZenmuxChat, as: ZenmuxChatProtocol
  alias ReqLlmNext.Wire.OpenAIChat

  @provider_option_keys [
    :provider,
    :model_routing_config,
    :reasoning,
    :web_search_options,
    :verbosity,
    :max_completion_tokens,
    :reasoning_effort
  ]

  @impl ReqLlmNext.Wire.Streaming
  def endpoint, do: OpenAIChat.endpoint()

  @impl ReqLlmNext.Wire.Streaming
  def encode_body(model, prompt, opts) do
    provider_options = provider_options(opts)

    max_completion_tokens =
      provider_options[:max_completion_tokens] || Keyword.get(opts, :max_tokens)

    model
    |> OpenAIChat.encode_body(prompt, Keyword.delete(opts, :max_tokens))
    |> Map.delete(:max_tokens)
    |> maybe_add(:max_completion_tokens, max_completion_tokens)
    |> maybe_add(:provider, provider_options[:provider])
    |> maybe_add(:model_routing_config, provider_options[:model_routing_config])
    |> maybe_add(:reasoning, provider_options[:reasoning])
    |> maybe_add(:web_search_options, provider_options[:web_search_options])
    |> maybe_add(:verbosity, provider_options[:verbosity])
    |> maybe_add(:reasoning_effort, encode_reasoning_effort(provider_options[:reasoning_effort]))
  end

  @impl ReqLlmNext.Wire.Streaming
  def options_schema do
    OpenAIChat.options_schema() ++
      [
        provider: [type: :map, doc: "Zenmux provider routing configuration"],
        model_routing_config: [type: :map, doc: "Zenmux model routing configuration"],
        reasoning: [type: :map, doc: "Zenmux reasoning configuration"],
        web_search_options: [type: :map, doc: "Zenmux web search configuration"],
        verbosity: [type: {:in, ["low", "medium", "high"]}, doc: "Zenmux verbosity mode"],
        max_completion_tokens: [type: :pos_integer, doc: "Zenmux max completion tokens"],
        reasoning_effort: [type: {:or, [:string, :atom]}, doc: "Zenmux reasoning effort"]
      ]
  end

  @impl ReqLlmNext.Wire.Streaming
  def decode_wire_event(event), do: OpenAIChat.decode_wire_event(event)

  @spec decode_sse_event(map(), LLMDB.Model.t() | nil) :: [term()]
  def decode_sse_event(event, model) do
    event
    |> decode_wire_event()
    |> Enum.flat_map(&ZenmuxChatProtocol.decode_event(&1, model))
  end

  defp provider_options(opts) do
    opts
    |> Keyword.get(:provider_options, [])
    |> normalize_provider_options()
    |> Keyword.merge(Keyword.take(opts, @provider_option_keys))
  end

  defp normalize_provider_options(opts) when is_map(opts), do: Map.to_list(opts)
  defp normalize_provider_options(opts) when is_list(opts), do: opts
  defp normalize_provider_options(_opts), do: []

  defp encode_reasoning_effort(nil), do: nil
  defp encode_reasoning_effort(:default), do: nil
  defp encode_reasoning_effort(effort) when is_atom(effort), do: Atom.to_string(effort)
  defp encode_reasoning_effort(effort) when is_binary(effort), do: effort
  defp encode_reasoning_effort(_effort), do: nil

  defp maybe_add(body, _key, nil), do: body
  defp maybe_add(body, key, value), do: Map.put(body, key, value)
end
