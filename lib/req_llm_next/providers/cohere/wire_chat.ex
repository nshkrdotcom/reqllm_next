defmodule ReqLlmNext.Wire.CohereChat do
  @moduledoc """
  Cohere Chat v2 streaming wire.
  """

  @behaviour ReqLlmNext.Wire.Streaming

  alias ReqLlmNext.Context
  alias ReqLlmNext.Context.ContentPart
  alias ReqLlmNext.Context.Message
  alias ReqLlmNext.Schema

  @provider_option_keys [
    :documents,
    :citation_options,
    :safety_mode,
    :seed,
    :frequency_penalty,
    :presence_penalty,
    :k,
    :p,
    :logprobs
  ]

  @impl ReqLlmNext.Wire.Streaming
  def endpoint, do: "/v2/chat"

  @impl ReqLlmNext.Wire.Streaming
  def encode_body(model, prompt, opts) do
    provider_options = provider_options(opts)

    %{
      "model" => model.id,
      "stream" => true,
      "messages" => encode_prompt(prompt)
    }
    |> maybe_put("response_format", response_format(opts))
    |> maybe_put("documents", normalize_documents(provider_options[:documents]))
    |> maybe_put("citation_options", provider_options[:citation_options])
    |> maybe_put("safety_mode", provider_options[:safety_mode])
    |> maybe_put("max_tokens", Keyword.get(opts, :max_tokens))
    |> maybe_put("temperature", Keyword.get(opts, :temperature))
    |> maybe_put("p", Keyword.get(opts, :top_p) || provider_options[:p])
    |> maybe_put("seed", provider_options[:seed])
    |> maybe_put("frequency_penalty", provider_options[:frequency_penalty])
    |> maybe_put("presence_penalty", provider_options[:presence_penalty])
    |> maybe_put("k", provider_options[:k])
    |> maybe_put("logprobs", provider_options[:logprobs])
  end

  @impl ReqLlmNext.Wire.Streaming
  def options_schema do
    [
      max_tokens: [type: :pos_integer, doc: "Maximum output tokens for Cohere responses"],
      temperature: [type: :float, doc: "Cohere sampling temperature"],
      top_p: [type: :float, doc: "Cohere p sampling"],
      documents: [type: {:list, :any}, doc: "Cohere retrieval documents"],
      citation_options: [type: :map, doc: "Cohere citation configuration"],
      safety_mode: [type: {:or, [:atom, :string]}, doc: "Cohere safety mode"],
      seed: [type: :integer, doc: "Cohere deterministic sampling seed"],
      frequency_penalty: [type: :float, doc: "Cohere frequency penalty"],
      presence_penalty: [type: :float, doc: "Cohere presence penalty"],
      k: [type: :integer, doc: "Cohere top-k sampling"],
      p: [type: :float, doc: "Cohere top-p sampling override"],
      logprobs: [type: :boolean, doc: "Request Cohere logprobs"]
    ]
  end

  @impl ReqLlmNext.Wire.Streaming
  def headers(_opts), do: [{"Content-Type", "application/json"}]

  @impl ReqLlmNext.Wire.Streaming
  def decode_wire_event(%{data: "[DONE]"}), do: [:done]

  def decode_wire_event(%{data: data}) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, decoded} when is_map(decoded) -> [decoded]
      {:ok, _decoded} -> []
      {:error, decode_error} -> [{:decode_error, decode_error}]
    end
  end

  def decode_wire_event(%{data: data}) when is_map(data), do: [data]
  def decode_wire_event(_event), do: []

  defp provider_options(opts) do
    opts
    |> Keyword.get(:provider_options, [])
    |> normalize_provider_options()
    |> Keyword.merge(Keyword.take(opts, @provider_option_keys))
  end

  defp normalize_provider_options(opts) when is_map(opts), do: Map.to_list(opts)
  defp normalize_provider_options(opts) when is_list(opts), do: opts
  defp normalize_provider_options(_opts), do: []

  defp response_format(opts) do
    case {Keyword.get(opts, :compiled_schema), Keyword.get(opts, :_structured_output_strategy)} do
      {%{schema: schema}, :native_json_schema} ->
        %{"type" => "json_object", "json_schema" => Schema.to_json(schema)}

      _ ->
        nil
    end
  end

  defp encode_prompt(prompt) when is_binary(prompt) do
    [%{"role" => "user", "content" => prompt}]
  end

  defp encode_prompt(%Context{messages: messages}) do
    messages
    |> Enum.map(&encode_message/1)
    |> Enum.reject(&is_nil/1)
  end

  defp encode_message(%Message{role: :system, content: content}) do
    case encode_message_content(content) do
      "" -> nil
      encoded -> %{"role" => "system", "content" => encoded}
    end
  end

  defp encode_message(%Message{role: :user, content: content}) do
    case encode_message_content(content) do
      "" -> nil
      encoded -> %{"role" => "user", "content" => encoded}
    end
  end

  defp encode_message(%Message{role: :assistant, tool_calls: tool_calls}) when tool_calls != [] do
    nil
  end

  defp encode_message(%Message{role: :assistant, content: content}) do
    case encode_message_content(content) do
      "" -> nil
      encoded -> %{"role" => "assistant", "content" => encoded}
    end
  end

  defp encode_message(%Message{role: :tool}), do: nil

  defp encode_message_content(parts) when is_list(parts) do
    parts
    |> Enum.flat_map(fn
      %ContentPart{type: :text, text: text} when is_binary(text) and text != "" -> [text]
      _other -> []
    end)
    |> Enum.join("\n")
  end

  defp normalize_documents(documents) when is_list(documents), do: documents
  defp normalize_documents(nil), do: nil
  defp normalize_documents(document), do: [document]

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
