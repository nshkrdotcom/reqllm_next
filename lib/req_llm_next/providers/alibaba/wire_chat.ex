defmodule ReqLlmNext.Wire.AlibabaChat do
  @moduledoc """
  Alibaba DashScope chat-completions wire built on the OpenAI-compatible happy path.
  """

  @behaviour ReqLlmNext.Wire.Streaming

  alias ReqLlmNext.Wire.OpenAIChat

  @provider_option_keys [
    :dashscope_parameters,
    :enable_search,
    :search_options,
    :enable_thinking,
    :thinking_budget,
    :top_k,
    :repetition_penalty,
    :enable_code_interpreter,
    :vl_high_resolution_images,
    :incremental_output
  ]

  @dashscope_parameter_keys [
    :enable_search,
    :search_options,
    :enable_thinking,
    :thinking_budget,
    :top_k,
    :repetition_penalty,
    :enable_code_interpreter,
    :vl_high_resolution_images,
    :incremental_output
  ]

  @impl ReqLlmNext.Wire.Streaming
  def endpoint, do: OpenAIChat.endpoint()

  @impl ReqLlmNext.Wire.Streaming
  def encode_body(model, prompt, opts) do
    provider_options = provider_options(opts)

    model
    |> OpenAIChat.encode_body(prompt, opts)
    |> merge_dashscope_parameters(dashscope_parameters(provider_options))
  end

  @impl ReqLlmNext.Wire.Streaming
  def options_schema do
    OpenAIChat.options_schema() ++
      [
        dashscope_parameters: [type: :map, doc: "Raw DashScope provider parameters"],
        enable_search: [type: :boolean, doc: "Enable DashScope search"],
        search_options: [type: :map, doc: "DashScope search configuration"],
        enable_thinking: [type: :boolean, doc: "Enable DashScope reasoning mode"],
        thinking_budget: [type: :pos_integer, doc: "DashScope thinking token budget"],
        top_k: [type: :integer, doc: "DashScope top-k sampling"],
        repetition_penalty: [type: :float, doc: "DashScope repetition penalty"],
        enable_code_interpreter: [type: :boolean, doc: "Enable DashScope code interpreter"],
        vl_high_resolution_images: [
          type: :boolean,
          doc: "Enable high-resolution vision input"
        ],
        incremental_output: [type: :boolean, doc: "Stream incremental output only"]
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

  defp dashscope_parameters(provider_options) do
    explicit =
      case Keyword.get(provider_options, :dashscope_parameters) do
        map when is_map(map) -> map
        _ -> %{}
      end

    derived =
      provider_options
      |> Keyword.take(@dashscope_parameter_keys)
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()

    case Map.merge(explicit, derived) do
      params when map_size(params) == 0 -> nil
      params -> params
    end
  end

  defp merge_dashscope_parameters(body, nil), do: body
  defp merge_dashscope_parameters(body, params), do: Map.merge(body, params)
end
