defmodule ReqLlmNext.SemanticProtocols.AnthropicMessages do
  @moduledoc false

  @behaviour ReqLlmNext.SemanticProtocol

  alias ReqLlmNext.Context.ContentPart
  alias ReqLlmNext.Response.Usage

  @impl ReqLlmNext.SemanticProtocol
  def decode_event(:done, _model), do: [nil]

  def decode_event({:decode_error, decode_error}, _model) do
    [
      {:error,
       %{
         message: "Failed to decode SSE event: #{inspect(decode_error)}",
         type: "decode_error"
       }}
    ]
  end

  def decode_event(%{"type" => "error", "error" => error}, _model) do
    message = error["message"] || "Unknown API error"
    error_type = error["type"] || "api_error"
    [{:error, %{message: message, type: error_type}}]
  end

  def decode_event(%{"type" => "message_start", "message" => %{"id" => id}}, _model)
      when is_binary(id) do
    [{:meta, %{response_id: id}}]
  end

  def decode_event(%{"type" => "message_stop"}, _model), do: [nil]

  def decode_event(%{"type" => "message_delta"} = event, model) do
    usage_events =
      case Map.get(event, "usage") do
        usage when is_map(usage) -> [{:usage, Usage.normalize(usage, model)}]
        _ -> []
      end

    meta_events =
      stop_reason_meta(Map.get(event, "delta")) ++ context_management_meta(Map.get(event, "context_management"))

    usage_events ++ meta_events
  end

  def decode_event(
        %{"type" => "content_block_delta", "delta" => %{"type" => "text_delta", "text" => text}},
        _model
      ) do
    [text]
  end

  def decode_event(
        %{
          "type" => "content_block_delta",
          "delta" => %{"type" => "thinking_delta", "thinking" => text}
        },
        _model
      ) do
    [{:thinking, text}]
  end

  def decode_event(
        %{
          "type" => "content_block_delta",
          "delta" => %{"type" => "thinking_delta", "text" => text}
        },
        _model
      ) do
    [{:thinking, text}]
  end

  def decode_event(%{"type" => "content_block_delta", "delta" => %{"text" => text}}, _model) do
    [text]
  end

  def decode_event(
        %{
          "type" => "content_block_start",
          "content_block" => %{"type" => "text", "text" => text} = block
        },
        _model
      )
      when is_binary(text) and text != "" do
    metadata = citation_metadata(block)

    case metadata do
      %{} when map_size(metadata) == 0 -> [text]
      _ -> [{:content_part, ContentPart.text(text, metadata)}]
    end
  end

  def decode_event(
        %{
          "type" => "content_block_start",
          "content_block" => %{"type" => "thinking"} = block
        },
        _model
      ) do
    text = block["thinking"] || block["text"] || ""
    chunks = if text != "", do: [{:thinking, text}], else: []
    [{:thinking_start, nil} | chunks]
  end

  def decode_event(
        %{
          "type" => "content_block_start",
          "index" => index,
          "content_block" => %{"type" => "tool_use"} = block
        },
        _model
      ) do
    [
      {:tool_call_start,
       %{
         index: index,
         id: block["id"],
         name: block["name"]
       }}
    ]
  end

  def decode_event(
        %{
          "type" => "content_block_start",
          "content_block" => %{"type" => "compaction"} = block
        },
        _model
      ) do
    [{:provider_item, Map.put(block, "anthropic_type", "compaction")}]
  end

  def decode_event(
        %{
          "type" => "content_block_start",
          "content_block" => %{"type" => "web_fetch_tool_result", "content" => content}
        },
        _model
      )
      when is_map(content) do
    normalize_web_fetch_result(content)
  end

  def decode_event(
        %{
          "type" => "content_block_start",
          "content_block" => %{"type" => "web_search_tool_result", "content" => content}
        },
        _model
      )
      when is_list(content) do
    Enum.flat_map(content, &normalize_web_search_result/1)
  end

  def decode_event(
        %{
          "type" => "content_block_start",
          "content_block" => %{"type" => "server_tool_use"} = block
        },
        _model
      ) do
    [{:meta, %{anthropic_server_tool_use: block}}]
  end

  def decode_event(
        %{
          "type" => "content_block_delta",
          "index" => index,
          "delta" => %{"type" => "input_json_delta", "partial_json" => json}
        },
        _model
      ) do
    [{:tool_call_delta, %{index: index, partial_json: json}}]
  end

  def decode_event(_event, _model), do: []

  defp normalize_web_search_result(%{"type" => "web_search_result"} = result) do
    title = result["title"] || "search_result"
    url = result["url"] || ""
    text = result["snippet"] || result["text"] || ""
    metadata = Map.drop(result, ["type", "title", "url", "snippet", "text"])
    [{:content_part, ContentPart.search_result(title, url, text, metadata)}]
  end

  defp normalize_web_search_result(%{"type" => "text", "text" => text}) when is_binary(text),
    do: [text]

  defp normalize_web_search_result(_result), do: []

  defp normalize_web_fetch_result(%{"type" => "web_fetch_result"} = result) do
    provider_item =
      result
      |> Map.put("anthropic_type", "web_fetch_result")
      |> then(&[{:provider_item, &1}])

    provider_item ++ normalize_web_fetch_document(result)
  end

  defp normalize_web_fetch_result(%{"type" => "web_fetch_tool_error"} = error) do
    [{:provider_item, Map.put(error, "anthropic_type", "web_fetch_tool_error")}]
  end

  defp normalize_web_fetch_result(_result), do: []

  defp normalize_web_fetch_document(%{
         "content" => %{"type" => "document", "source" => source} = document
       } = result)
       when is_map(source) do
    metadata =
      document
      |> Map.drop(["type", "source"])
      |> Map.merge(%{
        url: result["url"],
        retrieved_at: result["retrieved_at"],
        anthropic_type: :web_fetch_result
      })

    case source do
      %{"type" => "text", "data" => data} when is_binary(data) ->
        [{:content_part, ContentPart.document_text(data, metadata)}]

      %{"type" => "base64", "data" => data, "media_type" => media_type}
      when is_binary(data) and is_binary(media_type) ->
        case Base.decode64(data) do
          {:ok, decoded} -> [{:content_part, ContentPart.document_binary(decoded, media_type, metadata)}]
          :error -> []
        end

      _ ->
        []
    end
  end

  defp normalize_web_fetch_document(_result), do: []

  defp citation_metadata(%{"citations" => citations}) when is_list(citations),
    do: %{citations: citations}

  defp citation_metadata(_block), do: %{}

  defp stop_reason_meta(%{"stop_reason" => stop_reason}) do
    [
      {:meta,
       %{
         finish_reason: normalize_stop_reason(stop_reason),
         anthropic_stop_reason: stop_reason
       }}
    ]
  end

  defp stop_reason_meta(_delta), do: []

  defp context_management_meta(%{"applied_edits" => applied_edits} = context_management)
       when is_list(applied_edits) do
    [{:meta, %{anthropic_context_management: context_management, anthropic_applied_edits: applied_edits}}]
  end

  defp context_management_meta(context_management) when is_map(context_management) do
    [{:meta, %{anthropic_context_management: context_management}}]
  end

  defp context_management_meta(_context_management), do: []

  defp normalize_stop_reason("end_turn"), do: :stop
  defp normalize_stop_reason("stop_sequence"), do: :stop
  defp normalize_stop_reason("max_tokens"), do: :length
  defp normalize_stop_reason("tool_use"), do: :tool_calls
  defp normalize_stop_reason("pause_turn"), do: :stop
  defp normalize_stop_reason("compaction"), do: :stop
  defp normalize_stop_reason(_reason), do: nil
end
