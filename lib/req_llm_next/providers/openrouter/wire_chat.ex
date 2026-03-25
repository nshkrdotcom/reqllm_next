defmodule ReqLlmNext.Wire.OpenRouterChat do
  @moduledoc """
  OpenRouter chat-completions wire built on the OpenAI-compatible happy path.
  """

  @behaviour ReqLlmNext.Wire.Streaming

  alias ReqLlmNext.Wire.OpenAIChat

  @provider_option_keys [
    :openrouter_models,
    :openrouter_route,
    :openrouter_provider,
    :openrouter_transforms,
    :openrouter_top_k,
    :openrouter_repetition_penalty,
    :openrouter_min_p,
    :openrouter_top_a,
    :openrouter_top_logprobs,
    :openrouter_usage,
    :openrouter_plugins,
    :app_referer,
    :app_title
  ]

  @impl ReqLlmNext.Wire.Streaming
  def endpoint, do: OpenAIChat.endpoint()

  @impl ReqLlmNext.Wire.Streaming
  def encode_body(model, prompt, opts) do
    provider_options = provider_options(opts)

    model
    |> OpenAIChat.encode_body(prompt, opts)
    |> maybe_add(:models, provider_options[:openrouter_models])
    |> maybe_add(:route, provider_options[:openrouter_route])
    |> maybe_add(:provider, provider_options[:openrouter_provider])
    |> maybe_add(:transforms, provider_options[:openrouter_transforms])
    |> maybe_add(:top_k, provider_options[:openrouter_top_k])
    |> maybe_add(:repetition_penalty, provider_options[:openrouter_repetition_penalty])
    |> maybe_add(:min_p, provider_options[:openrouter_min_p])
    |> maybe_add(:top_a, provider_options[:openrouter_top_a])
    |> maybe_add(:top_logprobs, provider_options[:openrouter_top_logprobs])
    |> maybe_add(:usage, provider_options[:openrouter_usage])
    |> maybe_add(:plugins, provider_options[:openrouter_plugins])
  end

  @impl ReqLlmNext.Wire.Streaming
  def options_schema do
    OpenAIChat.options_schema() ++
      [
        openrouter_models: [type: {:list, :string}, doc: "OpenRouter routing model preferences"],
        openrouter_route: [type: :string, doc: "OpenRouter route strategy"],
        openrouter_provider: [type: :map, doc: "OpenRouter provider routing options"],
        openrouter_transforms: [type: {:list, :string}, doc: "OpenRouter prompt transforms"],
        openrouter_top_k: [type: :integer, doc: "OpenRouter top-k sampling"],
        openrouter_repetition_penalty: [type: :float, doc: "OpenRouter repetition penalty"],
        openrouter_min_p: [type: :float, doc: "OpenRouter minimum probability"],
        openrouter_top_a: [type: :float, doc: "OpenRouter top-a sampling"],
        openrouter_top_logprobs: [type: :integer, doc: "OpenRouter top logprobs"],
        openrouter_usage: [type: :map, doc: "OpenRouter usage options"],
        openrouter_plugins: [type: {:list, :map}, doc: "OpenRouter plugin declarations"],
        app_referer: [type: :string, doc: "OpenRouter HTTP-Referer header"],
        app_title: [type: :string, doc: "OpenRouter X-Title header"]
      ]
  end

  @impl ReqLlmNext.Wire.Streaming
  def decode_wire_event(event), do: OpenAIChat.decode_wire_event(event)

  @spec decode_sse_event(map(), LLMDB.Model.t() | nil) :: [term()]
  def decode_sse_event(event, model), do: OpenAIChat.decode_sse_event(event, model)

  @impl ReqLlmNext.Wire.Streaming
  @spec headers(keyword()) :: [{String.t(), String.t()}]
  def headers(opts) do
    provider_options = provider_options(opts)

    [{"Content-Type", "application/json"}]
    |> maybe_add_header("HTTP-Referer", provider_options[:app_referer])
    |> maybe_add_header("X-Title", provider_options[:app_title])
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

  defp maybe_add(body, _key, nil), do: body
  defp maybe_add(body, key, value), do: Map.put(body, key, value)

  defp maybe_add_header(headers, _name, nil), do: headers
  defp maybe_add_header(headers, name, value), do: headers ++ [{name, value}]
end
