defmodule ReqLlmNext.Wire.Anthropic do
  @moduledoc """
  Wire protocol for Anthropic Messages API.

  Handles encoding requests and decoding SSE events for /v1/messages endpoint.

  ## Extended Thinking

  Claude models support extended thinking (reasoning mode) where the model
  shows its reasoning process. Enable with the `:thinking` option:

      opts = [thinking: %{type: "enabled", budget_tokens: 4096}]

  Or use `:reasoning_effort` for simpler configuration:

      opts = [reasoning_effort: :medium]  # Mapped to budget_tokens: 2048

  When thinking is enabled:
  - Temperature must not be set (Anthropic requires default 1.0)
  - top_p must be 0.95-1.0, top_k is not allowed
  - max_tokens must exceed budget_tokens

  ## Prompt Caching

  Cache expensive prompts for faster responses:

      opts = [anthropic_prompt_cache: true]  # Adds cache_control to system

  """

  @behaviour ReqLlmNext.Wire.Streaming

  alias ReqLlmNext.Anthropic.Headers
  alias ReqLlmNext.Anthropic.Tools, as: AnthropicTools
  alias ReqLlmNext.Context.ContentPart
  alias ReqLlmNext.SemanticProtocols.AnthropicMessages, as: AnthropicMessagesProtocol
  alias ReqLlmNext.{Tool, ToolCall}

  @reasoning_budget_low 1024
  @reasoning_budget_medium 2048
  @reasoning_budget_high 4096

  @impl ReqLlmNext.Wire.Streaming
  @spec headers(keyword()) :: [{String.t(), String.t()}]
  def headers(opts \\ []), do: Headers.headers(opts)

  defp has_thinking?(opts) do
    Keyword.has_key?(opts, :thinking) or Keyword.has_key?(opts, :reasoning_effort)
  end

  defp has_prompt_caching?(opts) do
    Keyword.get(opts, :anthropic_prompt_cache, false) == true
  end

  @doc """
  Map reasoning effort level to budget tokens.

  ## Examples

      iex> ReqLlmNext.Wire.Anthropic.map_reasoning_effort_to_budget(:low)
      1024

      iex> ReqLlmNext.Wire.Anthropic.map_reasoning_effort_to_budget(:medium)
      2048

      iex> ReqLlmNext.Wire.Anthropic.map_reasoning_effort_to_budget(:high)
      4096
  """
  @spec map_reasoning_effort_to_budget(atom() | String.t()) :: non_neg_integer()
  def map_reasoning_effort_to_budget(:low), do: @reasoning_budget_low
  def map_reasoning_effort_to_budget(:medium), do: @reasoning_budget_medium
  def map_reasoning_effort_to_budget(:high), do: @reasoning_budget_high
  def map_reasoning_effort_to_budget("low"), do: @reasoning_budget_low
  def map_reasoning_effort_to_budget("medium"), do: @reasoning_budget_medium
  def map_reasoning_effort_to_budget("high"), do: @reasoning_budget_high
  def map_reasoning_effort_to_budget(_), do: @reasoning_budget_medium

  @impl ReqLlmNext.Wire.Streaming
  def endpoint, do: "/v1/messages"

  @impl ReqLlmNext.Wire.Streaming
  def encode_body(model, prompt, opts) do
    {messages, system_prompt} = encode_messages(prompt, opts)

    %{
      model: model.id,
      messages: messages,
      stream: true,
      max_tokens: Keyword.get(opts, :max_tokens, 1024)
    }
    |> maybe_add_system(system_prompt, opts)
    |> maybe_add_temperature(opts)
    |> maybe_add_thinking(opts)
    |> maybe_add_output_config(opts)
    |> maybe_add_tools(opts)
    |> maybe_add_tool_choice(opts)
    |> maybe_add_mcp_servers(opts)
    |> maybe_add_context_management(opts)
    |> maybe_add_container(opts)
  end

  defp maybe_add_system(body, nil, _opts), do: body

  defp maybe_add_system(body, system_prompt, opts) when is_binary(system_prompt) do
    if has_prompt_caching?(opts) do
      cache_control = cache_control_meta(opts)

      Map.put(body, :system, [
        %{type: "text", text: system_prompt, cache_control: cache_control}
      ])
    else
      Map.put(body, :system, system_prompt)
    end
  end

  defp maybe_add_system(body, system_blocks, opts) when is_list(system_blocks) do
    if has_prompt_caching?(opts) do
      cache_control = cache_control_meta(opts)
      cached_blocks = add_cache_control_to_last(system_blocks, cache_control)
      Map.put(body, :system, cached_blocks)
    else
      Map.put(body, :system, system_blocks)
    end
  end

  defp add_cache_control_to_last([], _cache_control), do: []

  defp add_cache_control_to_last(blocks, cache_control) do
    {last, rest} = List.pop_at(blocks, -1)
    rest ++ [Map.put(last, :cache_control, cache_control)]
  end

  defp cache_control_meta(opts) do
    case Keyword.get(opts, :anthropic_prompt_cache_ttl) do
      nil -> %{type: "ephemeral"}
      ttl -> %{type: "ephemeral", ttl: ttl}
    end
  end

  defp maybe_add_temperature(body, opts) do
    if has_thinking?(opts) do
      body
    else
      maybe_add(body, :temperature, Keyword.get(opts, :temperature))
    end
  end

  defp maybe_add_thinking(body, opts) do
    thinking = Keyword.get(opts, :thinking)
    reasoning_effort = Keyword.get(opts, :reasoning_effort)

    cond do
      is_map(thinking) ->
        Map.put(body, :thinking, thinking)

      not is_nil(reasoning_effort) ->
        budget = map_reasoning_effort_to_budget(reasoning_effort)
        Map.put(body, :thinking, %{type: "enabled", budget_tokens: budget})

      true ->
        body
    end
  end

  defp maybe_add_output_config(body, opts) do
    case {
      Keyword.get(opts, :operation),
      Keyword.get(opts, :compiled_schema),
      Keyword.get(opts, :_structured_output_strategy)
    } do
      {:object, %{schema: schema}, :native_json_schema} when not is_nil(schema) ->
        Map.put(body, :output_config, %{
          format: %{
            type: "json_schema",
            schema: ReqLlmNext.Schema.to_json(schema)
          }
        })

      _ ->
        body
    end
  end

  defp maybe_add_mcp_servers(body, opts) do
    case Keyword.get(opts, :mcp_servers) do
      servers when is_list(servers) and servers != [] ->
        Map.put(body, :mcp_servers, Enum.map(servers, &AnthropicTools.normalize_mcp_server/1))

      _ ->
        body
    end
  end

  defp maybe_add_context_management(body, opts) do
    case Keyword.get(opts, :context_management) do
      context_management when is_map(context_management) and map_size(context_management) > 0 ->
        Map.put(body, :context_management, context_management)

      _ ->
        body
    end
  end

  defp maybe_add_container(body, opts) do
    case Keyword.get(opts, :container) do
      container when is_map(container) and map_size(container) > 0 ->
        Map.put(body, :container, container)

      _ ->
        body
    end
  end

  defp encode_messages(prompt, _opts) when is_binary(prompt) do
    {[%{role: "user", content: prompt}], nil}
  end

  defp encode_messages(%ReqLlmNext.Context{messages: messages}, _opts) do
    {system_msg, other_msgs} = Enum.split_with(messages, &(&1.role == :system))

    system_prompt =
      case system_msg do
        [%{content: [%{text: text}]}] -> text
        _ -> nil
      end

    encoded = Enum.map(other_msgs, &encode_message/1)
    {encoded, system_prompt}
  end

  defp encode_message(%ReqLlmNext.Context.Message{role: :tool} = msg) do
    %{
      role: "user",
      content: [
        %{
          type: "tool_result",
          tool_use_id: msg.tool_call_id,
          content: encode_content(msg.content)
        }
      ]
    }
  end

  defp encode_message(%ReqLlmNext.Context.Message{role: :assistant, tool_calls: tool_calls} = msg)
       when is_list(tool_calls) and tool_calls != [] do
    content_parts =
      case msg.content do
        [%{type: :text, text: text}] when is_binary(text) and text != "" ->
          [%{type: "text", text: text}]

        _ ->
          []
      end

    tool_use_parts = Enum.map(tool_calls, &encode_tool_use/1)

    %{
      role: "assistant",
      content: content_parts ++ tool_use_parts
    }
  end

  defp encode_message(%ReqLlmNext.Context.Message{role: role, content: content}) do
    %{
      role: to_string(role),
      content: encode_content(content)
    }
  end

  defp encode_tool_use(%ToolCall{id: id, function: %{name: name, arguments: args_json}}) do
    %{
      type: "tool_use",
      id: id,
      name: name,
      input: Jason.decode!(args_json)
    }
  end

  defp encode_content([%{type: :text, text: text}]) when is_binary(text), do: text

  defp encode_content(parts) when is_list(parts) do
    Enum.map(parts, &encode_content_part/1)
  end

  defp encode_content_part(%{type: :text, text: text}), do: %{type: "text", text: text}

  defp encode_content_part(%ContentPart{type: :image, data: data, media_type: media_type}),
    do: %{
      type: "image",
      source: %{type: "base64", media_type: media_type, data: Base.encode64(data)}
    }

  defp encode_content_part(%{type: :image_url, url: url}) do
    case ContentPart.parse_data_uri(url) do
      {:ok, %{media_type: media_type, data: data}} ->
        %{
          type: "image",
          source: %{type: "base64", media_type: media_type, data: Base.encode64(data)}
        }

      :error ->
        %{type: "image", source: %{type: "url", url: url}}
    end
  end

  defp encode_content_part(%ContentPart{type: :document} = part) do
    part
    |> encode_document_part()
    |> maybe_add_document_title(part)
    |> maybe_add_document_context(part)
    |> maybe_add_document_citations(part)
  end

  defp encode_content_part(%ContentPart{type: :file} = part) do
    case anthropic_file_type(part) do
      :container_upload ->
        %{type: "container_upload", file_id: part.data}

      _ ->
        part
        |> coerce_file_to_document()
        |> encode_content_part()
    end
  end

  defp encode_content_part(%ContentPart{type: :search_result} = part) do
    metadata = part.metadata || %{}
    title = Map.get(metadata, :title) || Map.get(metadata, "title")
    encrypted_index = Map.get(metadata, :encrypted_index) || Map.get(metadata, "encrypted_index")

    %{
      type: "search_result",
      title: title,
      url: part.url,
      encrypted_index: encrypted_index,
      content: [%{type: "text", text: part.text || ""}]
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Enum.into(%{})
  end

  @impl ReqLlmNext.Wire.Streaming
  def options_schema do
    [
      max_tokens: [type: :pos_integer, default: 1024, doc: "Maximum tokens to generate"],
      temperature: [type: :float, doc: "Sampling temperature (0.0-1.0)"],
      top_p: [type: :float, doc: "Nucleus sampling parameter"],
      top_k: [type: :pos_integer, doc: "Top-k sampling parameter"]
    ]
  end

  defp maybe_add_tools(body, opts) do
    case Keyword.get(opts, :tools) do
      nil -> body
      [] -> body
      tools when is_list(tools) -> Map.put(body, :tools, Enum.map(tools, &encode_tool_def/1))
    end
  end

  defp encode_tool_def(%Tool{} = tool), do: Tool.to_schema(tool, :anthropic)
  defp encode_tool_def(tool) when is_map(tool), do: AnthropicTools.normalize_tool(tool)

  defp maybe_add_tool_choice(body, opts) do
    case Keyword.get(opts, :tool_choice) do
      nil -> body
      %{type: "tool", name: name} -> Map.put(body, :tool_choice, %{type: "tool", name: name})
      choice -> Map.put(body, :tool_choice, choice)
    end
  end

  @impl ReqLlmNext.Wire.Streaming
  def decode_wire_event(%{data: data}) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, decoded} when is_map(decoded) ->
        [decoded]

      {:ok, _decoded} ->
        []

      {:error, decode_error} ->
        [{:decode_error, decode_error}]
    end
  end

  def decode_wire_event(%{data: data}) when is_map(data), do: [data]
  def decode_wire_event(_event), do: []

  @spec decode_sse_event(map(), LLMDB.Model.t() | nil) :: [term()]
  def decode_sse_event(event, model) do
    event
    |> decode_wire_event()
    |> Enum.flat_map(&AnthropicMessagesProtocol.decode_event(&1, model))
  end

  defp maybe_add(body, _key, nil), do: body
  defp maybe_add(body, key, value), do: Map.put(body, key, value)

  defp encode_document_part(%ContentPart{data: data, url: url, media_type: media_type} = part) do
    %{
      type: "document",
      source: document_source(part, data, url, media_type || "application/pdf")
    }
  end

  defp document_source(%ContentPart{metadata: metadata}, file_id, _url, media_type)
       when is_binary(file_id) do
    source_type =
      Map.get(metadata || %{}, :source_type) || Map.get(metadata || %{}, "source_type")

    case source_type do
      :file_id -> %{type: "file", file_id: file_id}
      "file_id" -> %{type: "file", file_id: file_id}
      _ -> document_source_from_data(file_id, media_type)
    end
  end

  defp document_source(%ContentPart{}, _data, url, media_type) when is_binary(url) do
    %{type: "url", url: url, media_type: media_type}
  end

  defp document_source(%ContentPart{data: data}, _data, _url, media_type) when is_binary(data) do
    %{type: "base64", media_type: media_type, data: Base.encode64(data)}
  end

  defp document_source(%ContentPart{data: data}, _data, _url, _media_type) when is_list(data) do
    %{type: "content", content: Enum.map(data, &encode_document_content_block/1)}
  end

  defp document_source(_part, _data, _url, media_type) do
    %{type: "content", content: [%{type: "text", text: "", media_type: media_type}]}
  end

  defp document_source_from_data("file_" <> _rest = file_id, _media_type),
    do: %{type: "file", file_id: file_id}

  defp document_source_from_data(text, "text/plain"), do: %{type: "text", text: text}

  defp document_source_from_data(data, media_type) do
    %{type: "base64", media_type: media_type, data: Base.encode64(data)}
  end

  defp encode_document_content_block(%ContentPart{type: :text, text: text}),
    do: %{type: "text", text: text}

  defp encode_document_content_block(%ContentPart{type: :search_result} = part),
    do: encode_content_part(part)

  defp encode_document_content_block(%{type: :text, text: text}), do: %{type: "text", text: text}

  defp encode_document_content_block(%{type: :search_result} = part),
    do: encode_content_part(ContentPart.new!(part))

  defp encode_document_content_block(part), do: encode_content_part(part)

  defp maybe_add_document_title(block, %ContentPart{metadata: metadata}) do
    case Map.get(metadata || %{}, :title) || Map.get(metadata || %{}, "title") do
      title when is_binary(title) and title != "" -> Map.put(block, :title, title)
      _ -> block
    end
  end

  defp maybe_add_document_context(block, %ContentPart{metadata: metadata}) do
    case Map.get(metadata || %{}, :context) || Map.get(metadata || %{}, "context") do
      context when is_binary(context) and context != "" -> Map.put(block, :context, context)
      _ -> block
    end
  end

  defp maybe_add_document_citations(block, %ContentPart{metadata: metadata}) do
    case Map.get(metadata || %{}, :citations) || Map.get(metadata || %{}, "citations") do
      true -> Map.put(block, :citations, %{enabled: true})
      %{enabled: _enabled} = citations -> Map.put(block, :citations, citations)
      _ -> block
    end
  end

  defp anthropic_file_type(%ContentPart{metadata: metadata}) do
    Map.get(metadata || %{}, :anthropic_type) || Map.get(metadata || %{}, "anthropic_type")
  end

  defp coerce_file_to_document(%ContentPart{} = part) do
    %ContentPart{
      type: :document,
      data: part.data,
      url: part.url,
      media_type: part.media_type,
      filename: part.filename,
      metadata: part.metadata
    }
  end
end
