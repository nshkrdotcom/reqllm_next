defmodule ReqLlmNext.Wire.OpenAIResponses do
  @moduledoc """
  Wire protocol for OpenAI Responses API.

  Handles /v1/responses endpoint for reasoning models (o1, o3, o4, GPT-5).
  This API uses different request/response formats than the Chat Completions API:

  - Input uses "input" array with typed items instead of "messages"
  - System messages become role: "developer"
  - Uses max_output_tokens instead of max_tokens
  - Supports reasoning config with effort levels
  - Streaming uses different event types (response.*)
  - Reasoning content is streamed as thinking deltas
  """

  @behaviour ReqLlmNext.Wire.Streaming

  alias ReqLlmNext.Context.Message
  alias ReqLlmNext.Context.ContentPart
  alias ReqLlmNext.Families.OpenAICompatible.FileInput
  alias ReqLlmNext.OpenAI.Tools, as: OpenAITools
  alias ReqLlmNext.SemanticProtocols.OpenAIResponses, as: OpenAIResponsesProtocol
  alias ReqLlmNext.{Tool, ToolCall}

  @impl ReqLlmNext.Wire.Streaming
  def endpoint, do: "/v1/responses"

  @doc "Returns the path for the Responses API endpoint."
  @spec path() :: String.t()
  def path, do: "/v1/responses"

  @impl ReqLlmNext.Wire.Streaming
  def encode_body(model, prompt, opts) do
    base_body(model, prompt, opts)
    |> Map.put(:stream, true)
  end

  @spec encode_websocket_event(LLMDB.Model.t(), String.t() | ReqLlmNext.Context.t(), keyword()) ::
          map()
  def encode_websocket_event(model, prompt, opts) do
    model
    |> base_body(prompt, opts)
    |> Map.update!(:input, fn input ->
      Enum.map(input, fn item -> websocket_input_item(item) end)
    end)
    |> Map.put(:type, "response.create")
    |> maybe_add(:previous_response_id, Keyword.get(opts, :previous_response_id))
    |> maybe_add(:store, Keyword.get(opts, :store))
    |> maybe_add(:generate, Keyword.get(opts, :generate))
  end

  defp base_body(model, prompt, opts) do
    %{
      model: model.id,
      input: encode_input(prompt)
    }
    |> maybe_add(:max_output_tokens, get_max_tokens(opts))
    |> maybe_add(:temperature, Keyword.get(opts, :temperature))
    |> maybe_add(:include, Keyword.get(opts, :include))
    |> maybe_add(:prompt_cache_key, Keyword.get(opts, :prompt_cache_key))
    |> maybe_add(:prompt_cache_retention, encode_prompt_cache_retention(opts))
    |> maybe_add(:reasoning, encode_reasoning_effort(Keyword.get(opts, :reasoning_effort)))
    |> maybe_add(:truncation, Keyword.get(opts, :truncation))
    |> maybe_add_tools(opts)
    |> maybe_add_tool_choice(opts)
    |> maybe_add_response_format(opts)
  end

  defp get_max_tokens(opts) do
    Keyword.get(opts, :max_output_tokens) ||
      Keyword.get(opts, :max_completion_tokens) ||
      Keyword.get(opts, :max_tokens)
  end

  defp encode_input(prompt) when is_binary(prompt) do
    [%{role: "user", content: [%{type: "input_text", text: prompt}]}]
  end

  defp encode_input(%ReqLlmNext.Context{messages: messages}) do
    Enum.flat_map(messages, &encode_input_items/1)
  end

  defp encode_input_items(%Message{role: :tool} = msg), do: [encode_tool_output_item(msg)]

  defp encode_input_items(%Message{role: :assistant, tool_calls: tool_calls} = msg)
       when is_list(tool_calls) and tool_calls != [] do
    content_items =
      case encode_input_message(msg) do
        nil -> []
        message -> [message]
      end

    content_items ++ Enum.map(tool_calls, &encode_function_call_item/1)
  end

  defp encode_input_items(%Message{} = msg) do
    case encode_input_message(msg) do
      nil -> []
      message -> [message]
    end
  end

  defp encode_input_message(%ReqLlmNext.Context.Message{role: :system} = msg) do
    encode_message_item("developer", msg.content, "input_text")
  end

  defp encode_input_message(%ReqLlmNext.Context.Message{role: :assistant} = msg) do
    encode_message_item("assistant", msg.content, "output_text")
  end

  defp encode_input_message(%ReqLlmNext.Context.Message{role: role} = msg) do
    encode_message_item(to_string(role), msg.content, "input_text")
  end

  defp encode_message_item(role, content, content_type) do
    case encode_input_content(content, content_type) do
      [] -> nil
      encoded_content -> %{role: role, content: encoded_content}
    end
  end

  defp encode_input_content(parts, content_type) when is_list(parts) do
    Enum.flat_map(parts, fn part ->
      case part do
        %{type: :text, text: text} ->
          [%{type: content_type, text: text}]

        %ContentPart{type: :image} = image ->
          [%{type: "input_image", image_url: ContentPart.data_uri(image)}]

        %{type: :image_url, url: url} ->
          [%{type: "input_image", image_url: url}]

        %ContentPart{type: type} = part when type in [:file, :document] ->
          [Map.put(FileInput.encode(part), :type, "input_file")]

        _ ->
          []
      end
    end)
  end

  defp encode_function_call_item(%ToolCall{} = tool_call) do
    %{
      type: "function_call",
      call_id: tool_call.id,
      name: tool_call.function.name,
      arguments: tool_call.function.arguments
    }
  end

  defp encode_tool_output_item(%Message{tool_call_id: tool_call_id, content: content}) do
    %{
      type: "function_call_output",
      call_id: tool_call_id,
      output: encode_tool_output(content)
    }
  end

  defp encode_tool_output([%{type: :text, text: text}]) when is_binary(text), do: text
  defp encode_tool_output([%ContentPart{type: :text, text: text}]) when is_binary(text), do: text
  defp encode_tool_output(content), do: Jason.encode!(content)

  defp websocket_input_item(%{type: _type} = item), do: item
  defp websocket_input_item(%{"type" => _type} = item), do: item
  defp websocket_input_item(item), do: Map.put(item, :type, "message")

  defp encode_reasoning_effort(nil), do: nil
  defp encode_reasoning_effort(effort) when is_atom(effort), do: %{effort: Atom.to_string(effort)}
  defp encode_reasoning_effort(effort) when is_binary(effort), do: %{effort: effort}
  defp encode_reasoning_effort(_), do: nil

  defp encode_prompt_cache_retention(opts) do
    case Keyword.get(opts, :prompt_cache_retention) do
      :in_memory -> "in_memory"
      "in_memory" -> "in_memory"
      "24h" = retention -> retention
      _ -> nil
    end
  end

  defp maybe_add_tools(body, opts) do
    case Keyword.get(opts, :tools) do
      nil -> body
      [] -> body
      tools when is_list(tools) -> Map.put(body, :tools, Enum.map(tools, &encode_tool_def/1))
    end
  end

  defp encode_tool_def(%Tool{} = tool), do: encode_responses_tool(tool)

  defp encode_tool_def(tool) when is_map(tool) do
    case OpenAITools.encode_provider_native_tool(tool) do
      {:ok, encoded_tool} ->
        encoded_tool

      :error ->
        raise ArgumentError,
              "OpenAI Responses surfaces require ReqLlmNext.Tool values or ReqLlmNext.OpenAI helper maps"
    end
  end

  defp encode_responses_tool(%Tool{} = tool) do
    json_schema = Tool.to_schema(tool, :openai)
    function_def = json_schema["function"] || json_schema[:function]

    %{
      type: "function",
      name: function_def["name"] || function_def[:name],
      description: function_def["description"] || function_def[:description],
      parameters: function_def["parameters"] || function_def[:parameters],
      strict: tool.strict
    }
  end

  defp maybe_add_tool_choice(body, opts) do
    case Keyword.get(opts, :tool_choice) do
      nil ->
        body

      %{type: "function", function: %{name: name}} ->
        Map.put(body, :tool_choice, %{type: "function", name: name})

      %{type: "tool", name: name} ->
        Map.put(body, :tool_choice, %{type: "function", name: name})

      :auto ->
        Map.put(body, :tool_choice, "auto")

      :none ->
        Map.put(body, :tool_choice, "none")

      :required ->
        Map.put(body, :tool_choice, "required")

      "auto" ->
        Map.put(body, :tool_choice, "auto")

      "none" ->
        Map.put(body, :tool_choice, "none")

      "required" ->
        Map.put(body, :tool_choice, "required")

      _ ->
        body
    end
  end

  defp maybe_add_response_format(body, opts) do
    case {
      Keyword.get(opts, :operation),
      Keyword.get(opts, :compiled_schema),
      Keyword.get(opts, :_structured_output_strategy)
    } do
      {:object, %{schema: schema}, :native_json_schema} when not is_nil(schema) ->
        json_schema = ReqLlmNext.Schema.to_json(schema)

        Map.put(body, :text, %{
          format: %{
            type: "json_schema",
            name: "object",
            strict: true,
            schema: json_schema
          }
        })

      _ ->
        body
    end
  end

  @impl ReqLlmNext.Wire.Streaming
  def options_schema do
    [
      max_output_tokens: [type: :pos_integer, doc: "Maximum output tokens to generate"],
      max_completion_tokens: [type: :pos_integer, doc: "Alias for max_output_tokens"],
      max_tokens: [type: :pos_integer, doc: "Alias for max_output_tokens (normalized)"],
      prompt_cache_key: [type: :string, doc: "Cache routing key for prompt caching"],
      prompt_cache_retention: [
        type: {:in, [:in_memory, "in_memory", "24h"]},
        doc: "Prompt cache retention policy"
      ],
      include: [type: {:list, :string}, doc: "Additional response paths to include"],
      reasoning_effort: [
        type: {:in, [:minimal, :low, :medium, :high, "minimal", "low", "medium", "high"]},
        doc: "Control computation intensity for reasoning"
      ],
      truncation: [type: :string, doc: "Responses truncation mode"]
    ]
  end

  @impl ReqLlmNext.Wire.Streaming
  def decode_wire_event(%{data: "[DONE]"}), do: [:done]

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
    |> Enum.flat_map(&OpenAIResponsesProtocol.decode_event(&1, model))
  end

  defp maybe_add(body, _key, nil), do: body
  defp maybe_add(body, key, value), do: Map.put(body, key, value)
end
