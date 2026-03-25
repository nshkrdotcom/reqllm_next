defmodule ReqLlmNext.Wire.DeepSeekChat do
  @moduledoc """
  DeepSeek chat-completions wire built on the OpenAI-compatible happy path.
  """

  @behaviour ReqLlmNext.Wire.Streaming

  alias ReqLlmNext.SemanticProtocols.DeepSeekChat, as: DeepSeekChatProtocol
  alias ReqLlmNext.Wire.OpenAIChat

  @impl ReqLlmNext.Wire.Streaming
  def endpoint, do: OpenAIChat.endpoint()

  @impl ReqLlmNext.Wire.Streaming
  def encode_body(model, prompt, opts) do
    model
    |> OpenAIChat.encode_body(prompt, opts)
    |> maybe_add(:thinking, encode_thinking(opts))
  end

  @impl ReqLlmNext.Wire.Streaming
  def options_schema, do: OpenAIChat.options_schema()

  @impl ReqLlmNext.Wire.Streaming
  def decode_wire_event(event), do: OpenAIChat.decode_wire_event(event)

  @spec decode_sse_event(map(), LLMDB.Model.t() | nil) :: [term()]
  def decode_sse_event(event, model) do
    event
    |> decode_wire_event()
    |> Enum.flat_map(&DeepSeekChatProtocol.decode_event(&1, model))
  end

  defp encode_thinking(opts) do
    cond do
      is_map(Keyword.get(opts, :thinking)) ->
        Keyword.get(opts, :thinking)

      Keyword.get(opts, :reasoning) == :off ->
        %{type: "disabled"}

      Keyword.has_key?(opts, :thinking) ->
        %{type: "enabled"}

      Keyword.has_key?(opts, :reasoning_effort) ->
        %{type: "enabled"}

      true ->
        nil
    end
  end

  defp maybe_add(body, _key, nil), do: body
  defp maybe_add(body, key, value), do: Map.put(body, key, value)
end
