defmodule ReqLlmNext.Wire.ZAIChat do
  @moduledoc """
  Z.AI chat-completions wire built on the OpenAI-compatible happy path.
  """

  @behaviour ReqLlmNext.Wire.Streaming

  alias ReqLlmNext.SemanticProtocols.ZAIChat, as: ZAIChatProtocol
  alias ReqLlmNext.Wire.OpenAIChat

  @impl ReqLlmNext.Wire.Streaming
  def endpoint, do: OpenAIChat.endpoint()

  @impl ReqLlmNext.Wire.Streaming
  def encode_body(model, prompt, opts) do
    model
    |> OpenAIChat.encode_body(prompt, opts)
    |> maybe_add(:thinking, Keyword.get(opts, :thinking))
  end

  @impl ReqLlmNext.Wire.Streaming
  def options_schema,
    do:
      OpenAIChat.options_schema() ++
        [thinking: [type: :map, doc: "Z.AI thinking mode configuration"]]

  @impl ReqLlmNext.Wire.Streaming
  def decode_wire_event(event), do: OpenAIChat.decode_wire_event(event)

  @spec decode_sse_event(map(), LLMDB.Model.t() | nil) :: [term()]
  def decode_sse_event(event, model) do
    event
    |> decode_wire_event()
    |> Enum.flat_map(&ZAIChatProtocol.decode_event(&1, model))
  end

  defp maybe_add(body, _key, nil), do: body
  defp maybe_add(body, key, value), do: Map.put(body, key, value)
end
