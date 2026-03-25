defmodule ReqLlmNext.Wire.ZenmuxResponses do
  @moduledoc """
  Zenmux Responses wire built on the OpenAI-compatible Responses request shape.
  """

  @behaviour ReqLlmNext.Wire.Streaming

  alias ReqLlmNext.Wire.OpenAIResponses

  @provider_option_keys [
    :provider,
    :model_routing_config,
    :reasoning,
    :verbosity
  ]

  @impl ReqLlmNext.Wire.Streaming
  def endpoint, do: OpenAIResponses.endpoint()

  @spec path() :: String.t()
  def path, do: OpenAIResponses.path()

  @impl ReqLlmNext.Wire.Streaming
  def encode_body(model, prompt, opts) do
    build_request_body(model, prompt, opts)
    |> Map.put(:stream, true)
  end

  @spec build_request_body(LLMDB.Model.t(), String.t() | ReqLlmNext.Context.t(), keyword()) ::
          map()
  def build_request_body(model, prompt, opts) do
    provider_options = provider_options(opts)

    model
    |> OpenAIResponses.build_request_body(prompt, opts)
    |> maybe_add(:provider, provider_options[:provider])
    |> maybe_add(:model_routing_config, provider_options[:model_routing_config])
    |> merge_reasoning(provider_options[:reasoning])
    |> maybe_add(:verbosity, provider_options[:verbosity])
  end

  @impl ReqLlmNext.Wire.Streaming
  def options_schema do
    OpenAIResponses.options_schema() ++
      [
        provider: [type: :map, doc: "Zenmux provider routing configuration"],
        model_routing_config: [type: :map, doc: "Zenmux model routing configuration"],
        reasoning: [type: :map, doc: "Zenmux reasoning configuration"],
        verbosity: [type: {:in, ["low", "medium", "high"]}, doc: "Zenmux verbosity mode"]
      ]
  end

  @impl ReqLlmNext.Wire.Streaming
  def decode_wire_event(event), do: OpenAIResponses.decode_wire_event(event)

  @spec decode_sse_event(map(), LLMDB.Model.t() | nil) :: [term()]
  def decode_sse_event(event, model), do: OpenAIResponses.decode_sse_event(event, model)

  defp provider_options(opts) do
    opts
    |> Keyword.get(:provider_options, [])
    |> normalize_provider_options()
    |> Keyword.merge(Keyword.take(opts, @provider_option_keys))
  end

  defp normalize_provider_options(opts) when is_map(opts), do: Map.to_list(opts)
  defp normalize_provider_options(opts) when is_list(opts), do: opts
  defp normalize_provider_options(_opts), do: []

  defp merge_reasoning(body, nil), do: body

  defp merge_reasoning(body, provider_reasoning) when is_map(provider_reasoning) do
    existing =
      case Map.get(body, :reasoning) do
        map when is_map(map) -> map
        _ -> %{}
      end

    Map.put(body, :reasoning, Map.merge(existing, provider_reasoning))
  end

  defp maybe_add(body, _key, nil), do: body
  defp maybe_add(body, key, value), do: Map.put(body, key, value)
end
