defmodule ReqLlmNext.SemanticProtocols.AnthropicMessages do
  @moduledoc false

  @behaviour ReqLlmNext.SemanticProtocol

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

  def decode_event(%{"type" => "message_stop"}, _model), do: [nil]

  def decode_event(%{"type" => "message_delta", "usage" => usage}, model) when is_map(usage) do
    [{:usage, Usage.normalize(usage, model)}]
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
          "type" => "content_block_delta",
          "index" => index,
          "delta" => %{"type" => "input_json_delta", "partial_json" => json}
        },
        _model
      ) do
    [{:tool_call_delta, %{index: index, partial_json: json}}]
  end

  def decode_event(_event, _model), do: []
end
