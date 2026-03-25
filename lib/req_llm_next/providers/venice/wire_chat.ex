defmodule ReqLlmNext.Wire.VeniceChat do
  @moduledoc """
  Venice chat-completions wire built on the OpenAI-compatible happy path.
  """

  @behaviour ReqLlmNext.Wire.Streaming

  alias ReqLlmNext.Wire.OpenAIChat

  @provider_option_keys [
    :venice_parameters,
    :character_slug,
    :strip_thinking_response,
    :disable_thinking,
    :enable_web_search,
    :enable_web_scraping,
    :enable_web_citations,
    :include_search_results_in_stream,
    :return_search_results_as_documents,
    :include_venice_system_prompt
  ]

  @venice_parameter_keys [
    :character_slug,
    :strip_thinking_response,
    :disable_thinking,
    :enable_web_search,
    :enable_web_scraping,
    :enable_web_citations,
    :include_search_results_in_stream,
    :return_search_results_as_documents,
    :include_venice_system_prompt
  ]

  @impl ReqLlmNext.Wire.Streaming
  def endpoint, do: OpenAIChat.endpoint()

  @impl ReqLlmNext.Wire.Streaming
  def encode_body(model, prompt, opts) do
    provider_options = provider_options(opts)

    model
    |> OpenAIChat.encode_body(prompt, opts)
    |> maybe_add(:venice_parameters, venice_parameters(provider_options))
  end

  @impl ReqLlmNext.Wire.Streaming
  def options_schema do
    OpenAIChat.options_schema() ++
      [
        venice_parameters: [type: :map, doc: "Raw Venice provider parameters"],
        character_slug: [type: :string, doc: "Venice character slug"],
        strip_thinking_response: [type: :boolean, doc: "Strip thinking blocks from output"],
        disable_thinking: [type: :boolean, doc: "Disable Venice reasoning mode"],
        enable_web_search: [type: {:in, ["off", "on", "auto"]}, doc: "Venice web search mode"],
        enable_web_scraping: [type: :boolean, doc: "Enable Venice URL scraping"],
        enable_web_citations: [type: :boolean, doc: "Include web citations in output"],
        include_search_results_in_stream: [
          type: :boolean,
          doc: "Include Venice search results in stream chunks"
        ],
        return_search_results_as_documents: [
          type: :boolean,
          doc: "Return Venice search results as tool-call documents"
        ],
        include_venice_system_prompt: [
          type: :boolean,
          doc: "Include Venice default system prompt"
        ]
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

  defp venice_parameters(provider_options) do
    explicit =
      case Keyword.get(provider_options, :venice_parameters) do
        map when is_map(map) -> map
        _ -> %{}
      end

    derived =
      provider_options
      |> Keyword.take(@venice_parameter_keys)
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()

    case Map.merge(explicit, derived) do
      params when map_size(params) == 0 -> nil
      params -> params
    end
  end

  defp maybe_add(body, _key, nil), do: body
  defp maybe_add(body, key, value), do: Map.put(body, key, value)
end
