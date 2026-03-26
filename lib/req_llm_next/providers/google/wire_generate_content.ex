defmodule ReqLlmNext.Wire.GoogleGenerateContent do
  @moduledoc """
  Google Gemini generateContent wire.
  """

  @behaviour ReqLlmNext.Wire.Streaming

  alias ReqLlmNext.Context
  alias ReqLlmNext.Context.ContentPart
  alias ReqLlmNext.Context.Message
  alias ReqLlmNext.Tool
  alias ReqLlmNext.ToolCall

  @provider_option_keys [
    :google_api_version,
    :google_safety_settings,
    :google_candidate_count,
    :google_grounding,
    :google_url_context,
    :google_thinking_budget,
    :google_thinking_level,
    :cached_content,
    :top_k
  ]

  @impl ReqLlmNext.Wire.Streaming
  def endpoint, do: "/models"

  @impl ReqLlmNext.Wire.Streaming
  def build_request(provider_mod, model, prompt, opts) do
    api_key = provider_mod.get_api_key(opts)
    base_url = effective_base_url(provider_mod.base_url(), provider_options(opts))
    url = "#{base_url}/models/#{model.id}:streamGenerateContent?alt=sse"

    headers =
      provider_mod.auth_headers(api_key) ++
        headers(opts) ++
        [{"Accept", "text/event-stream"}]

    body =
      model
      |> encode_body(prompt, opts)
      |> Jason.encode!()

    {:ok, Finch.build(:post, url, headers, body)}
  end

  @impl ReqLlmNext.Wire.Streaming
  def encode_body(model, prompt, opts) do
    provider_options = provider_options(opts)
    {system_instruction, contents} = encode_prompt(prompt)

    generation_config =
      %{}
      |> maybe_put(:temperature, Keyword.get(opts, :temperature))
      |> maybe_put(:maxOutputTokens, Keyword.get(opts, :max_tokens))
      |> maybe_put(:topP, Keyword.get(opts, :top_p))
      |> maybe_put(:topK, provider_options[:top_k])
      |> maybe_put(:candidateCount, provider_options[:google_candidate_count] || 1)
      |> maybe_add_thinking_config(
        provider_options[:google_thinking_budget],
        provider_options[:google_thinking_level]
      )
      |> maybe_add_object_schema(model, opts)

    %{}
    |> maybe_put(:systemInstruction, system_instruction)
    |> Map.put(:contents, contents)
    |> merge_tools(opts, provider_options)
    |> maybe_put(:generationConfig, generation_config)
    |> maybe_put(:safetySettings, provider_options[:google_safety_settings])
    |> maybe_put(:cachedContent, provider_options[:cached_content])
  end

  @impl ReqLlmNext.Wire.Streaming
  def options_schema do
    [
      max_tokens: [type: :pos_integer, doc: "Maximum output tokens for Gemini responses"],
      temperature: [type: :float, doc: "Gemini sampling temperature"],
      top_p: [type: :float, doc: "Gemini top-p sampling"],
      top_k: [type: :integer, doc: "Gemini top-k sampling"],
      google_api_version: [type: {:in, ["v1", "v1beta"]}, doc: "Gemini API version"],
      google_safety_settings: [type: {:list, :map}, doc: "Gemini safety settings"],
      google_candidate_count: [type: :pos_integer, doc: "Gemini candidate count"],
      google_grounding: [type: :map, doc: "Gemini Google Search grounding config"],
      google_url_context: [type: {:or, [:boolean, :map]}, doc: "Gemini URL context tool config"],
      google_thinking_budget: [type: :non_neg_integer, doc: "Gemini thinking budget"],
      google_thinking_level: [type: {:or, [:atom, :string]}, doc: "Gemini thinking level"],
      cached_content: [type: :string, doc: "Gemini cached content reference"]
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

  defp effective_base_url(base_url, provider_options) do
    case provider_options[:google_api_version] do
      "v1" -> base_url <> "/v1"
      _ -> base_url <> "/v1beta"
    end
  end

  defp encode_prompt(prompt) when is_binary(prompt) do
    {nil, [%{role: "user", parts: [%{text: prompt}]}]}
  end

  defp encode_prompt(%Context{messages: messages}) do
    {system_parts, non_system_messages} = Enum.split_with(messages, &(&1.role == :system))

    system_instruction =
      case Enum.flat_map(system_parts, &encode_message_parts(&1.content)) do
        [] -> nil
        parts -> %{parts: parts}
      end

    contents =
      non_system_messages
      |> Enum.map(&encode_message/1)
      |> Enum.reject(&is_nil/1)
      |> merge_consecutive_roles()

    {system_instruction, contents}
  end

  defp encode_message(%Message{role: :assistant, tool_calls: tool_calls, content: content})
       when is_list(tool_calls) and tool_calls != [] do
    parts =
      (encode_message_parts(content) ++
         Enum.map(tool_calls, &encode_function_call_part/1))
      |> Enum.reject(&is_nil/1)

    %{role: "model", parts: parts}
  end

  defp encode_message(%Message{role: :assistant, content: content}) do
    case encode_message_parts(content) do
      [] -> nil
      parts -> %{role: "model", parts: parts}
    end
  end

  defp encode_message(%Message{role: :user, content: content}) do
    case encode_message_parts(content) do
      [] -> nil
      parts -> %{role: "user", parts: parts}
    end
  end

  defp encode_message(%Message{role: :tool, name: name, content: content}) when is_binary(name) do
    response =
      case tool_response_payload(content) do
        map when is_map(map) -> map
        text when is_binary(text) -> %{content: text}
      end

    %{role: "user", parts: [%{functionResponse: %{name: name, response: response}}]}
  end

  defp encode_message(%Message{role: :tool}), do: nil

  defp encode_message_parts(parts) when is_list(parts) do
    Enum.flat_map(parts, fn
      %ContentPart{type: :text, text: text} when is_binary(text) and text != "" ->
        [%{text: text}]

      %ContentPart{type: :image} = part ->
        [%{inlineData: %{mimeType: part.media_type, data: Base.encode64(part.data)}}]

      %ContentPart{type: :image_url, url: url} ->
        encode_uri_part(url, "image/jpeg")

      %ContentPart{type: :file} = part ->
        [
          %{
            inlineData: %{
              mimeType: part.media_type || "application/octet-stream",
              data: Base.encode64(part.data)
            }
          }
        ]

      %ContentPart{type: :document, data: data, media_type: media_type} when is_binary(data) ->
        [%{inlineData: %{mimeType: media_type || "application/pdf", data: Base.encode64(data)}}]

      %ContentPart{type: :document, url: url, media_type: media_type} when is_binary(url) ->
        encode_uri_part(url, media_type || "application/pdf")

      _other ->
        []
    end)
  end

  defp encode_uri_part("data:" <> _rest = url, fallback_mime) do
    case ContentPart.parse_data_uri(url) do
      {:ok, %{media_type: media_type, data: data}} ->
        [%{inlineData: %{mimeType: media_type, data: Base.encode64(data)}}]

      :error ->
        [%{fileData: %{mimeType: fallback_mime, fileUri: url}}]
    end
  end

  defp encode_uri_part(url, mime_type) when is_binary(url) do
    [%{fileData: %{mimeType: mime_type, fileUri: url}}]
  end

  defp merge_consecutive_roles([]), do: []

  defp merge_consecutive_roles([first | rest]) do
    {merged, last} =
      Enum.reduce(rest, {[], first}, fn
        %{role: role, parts: parts}, {acc, %{role: role} = current} ->
          {acc, %{current | parts: current.parts ++ parts}}

        entry, {acc, current} ->
          {acc ++ [current], entry}
      end)

    merged ++ [last]
  end

  defp encode_function_call_part(%ToolCall{function: %{name: name, arguments: arguments}}) do
    %{functionCall: %{name: name, args: decode_json(arguments)}}
  end

  defp encode_function_call_part(_tool_call), do: nil

  defp tool_response_payload([%{type: :text, text: text}]) when is_binary(text) do
    decode_json(text)
  end

  defp tool_response_payload([%ContentPart{type: :text, text: text}]) when is_binary(text) do
    decode_json(text)
  end

  defp tool_response_payload(content), do: %{content: Jason.encode!(content)}

  defp decode_json(text) when is_binary(text) do
    case Jason.decode(text) do
      {:ok, decoded} -> decoded
      {:error, _reason} -> text
    end
  end

  defp merge_tools(body, opts, provider_options) do
    builtin_tools = build_builtin_tools(provider_options)
    tools = Keyword.get(opts, :tools, [])

    all_tools =
      builtin_tools ++
        case tools do
          [] ->
            []

          list when is_list(list) ->
            [%{functionDeclarations: Enum.map(list, &Tool.to_schema(&1, :google))}]
        end

    tool_config = build_tool_config(Keyword.get(opts, :tool_choice))

    body
    |> maybe_put(:tools, if(all_tools == [], do: nil, else: all_tools))
    |> maybe_put(:toolConfig, if(all_tools == [], do: nil, else: tool_config))
  end

  defp build_builtin_tools(provider_options) do
    []
    |> maybe_append_builtin_tool(build_grounding_tool(provider_options[:google_grounding]))
    |> maybe_append_builtin_tool(build_url_context_tool(provider_options[:google_url_context]))
  end

  defp maybe_append_builtin_tool(tools, nil), do: tools
  defp maybe_append_builtin_tool(tools, tool), do: tools ++ [tool]

  defp build_grounding_tool(nil), do: nil
  defp build_grounding_tool(%{enable: true}), do: %{"googleSearch" => %{}}

  defp build_grounding_tool(%{dynamic_retrieval: config}) when is_map(config) do
    %{"googleSearchRetrieval" => %{"dynamicRetrievalConfig" => config}}
  end

  defp build_grounding_tool(_grounding), do: nil

  defp build_url_context_tool(true), do: %{"urlContext" => %{}}
  defp build_url_context_tool(%{} = config), do: %{"urlContext" => config}
  defp build_url_context_tool(_grounding), do: nil

  defp build_tool_config(nil), do: nil
  defp build_tool_config(:required), do: build_tool_config("required")
  defp build_tool_config(:auto), do: build_tool_config("auto")
  defp build_tool_config(:none), do: build_tool_config("none")

  defp build_tool_config(%{type: "function", function: %{name: name}}) do
    %{"functionCallingConfig" => %{"mode" => "ANY", "allowedFunctionNames" => [name]}}
  end

  defp build_tool_config(%{type: "tool", name: name}) do
    %{"functionCallingConfig" => %{"mode" => "ANY", "allowedFunctionNames" => [name]}}
  end

  defp build_tool_config("required"), do: %{"functionCallingConfig" => %{"mode" => "ANY"}}
  defp build_tool_config("auto"), do: %{"functionCallingConfig" => %{"mode" => "AUTO"}}
  defp build_tool_config("none"), do: %{"functionCallingConfig" => %{"mode" => "NONE"}}
  defp build_tool_config(_choice), do: nil

  defp maybe_add_thinking_config(config, nil, nil), do: config

  defp maybe_add_thinking_config(config, 0, nil),
    do: Map.put(config, :thinkingConfig, %{thinkingBudget: 0})

  defp maybe_add_thinking_config(config, budget, nil) when is_integer(budget) and budget > 0 do
    Map.put(config, :thinkingConfig, %{thinkingBudget: budget, includeThoughts: true})
  end

  defp maybe_add_thinking_config(config, nil, level) do
    Map.put(config, :thinkingConfig, %{thinkingLevel: to_string(level), includeThoughts: true})
  end

  defp maybe_add_thinking_config(config, _budget, _level), do: config

  defp maybe_add_object_schema(config, _model, opts) do
    case {
      Keyword.get(opts, :operation),
      Keyword.get(opts, :compiled_schema),
      Keyword.get(opts, :_structured_output_strategy)
    } do
      {:object, %{schema: schema}, :native_json_schema} when not is_nil(schema) ->
        json_schema = ReqLlmNext.Schema.to_json(schema)

        config
        |> Map.put(:responseMimeType, "application/json")
        |> Map.put(:responseJsonSchema, json_schema)

      _ ->
        config
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, []), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
