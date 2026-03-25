defmodule ReqLlmNext.Wire.GroqChat do
  @moduledoc """
  Groq chat-completions wire built on the OpenAI-compatible happy path.
  """

  @behaviour ReqLlmNext.Wire.Streaming

  alias ReqLlmNext.Wire.OpenAIChat

  @provider_option_keys [
    :service_tier,
    :reasoning_effort,
    :reasoning_format,
    :search_settings,
    :compound_custom,
    :logit_bias
  ]

  @impl ReqLlmNext.Wire.Streaming
  def endpoint, do: OpenAIChat.endpoint()

  @impl ReqLlmNext.Wire.Streaming
  def encode_body(model, prompt, opts) do
    provider_options = provider_options(opts)

    model
    |> OpenAIChat.encode_body(prompt, opts)
    |> maybe_add(:service_tier, provider_options[:service_tier])
    |> maybe_add(:reasoning_effort, encode_reasoning_effort(provider_options[:reasoning_effort]))
    |> maybe_add(:reasoning_format, provider_options[:reasoning_format])
    |> maybe_add(:search_settings, provider_options[:search_settings])
    |> maybe_add(:compound_custom, provider_options[:compound_custom])
    |> maybe_add(:logit_bias, provider_options[:logit_bias])
  end

  @impl ReqLlmNext.Wire.Streaming
  def options_schema do
    OpenAIChat.options_schema() ++
      [
        service_tier: [type: :string, doc: "Groq service tier"],
        reasoning_effort: [type: {:or, [:string, :atom]}, doc: "Groq reasoning effort"],
        reasoning_format: [type: :string, doc: "Groq reasoning format"],
        search_settings: [type: :map, doc: "Groq search settings"],
        compound_custom: [type: :map, doc: "Groq Compound custom configuration"],
        logit_bias: [type: :map, doc: "Groq token bias map"]
      ]
  end

  @impl ReqLlmNext.Wire.Streaming
  def decode_wire_event(event), do: OpenAIChat.decode_wire_event(event)

  @spec decode_sse_event(map(), LLMDB.Model.t() | nil) :: [term()]
  def decode_sse_event(event, model), do: OpenAIChat.decode_sse_event(event, model)

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
