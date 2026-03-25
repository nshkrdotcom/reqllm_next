defmodule ReqLlmNext.TestSupport.FakeRealtimeAdapter do
  @moduledoc false

  @behaviour ReqLlmNext.Realtime.Adapter

  alias ReqLlmNext.Realtime.{Command, Event}

  @impl ReqLlmNext.Realtime.Adapter
  def encode_command(_model, %Command{type: :session_update, data: data}, _opts) when is_map(data) do
    %{event: "session.configure", payload: data}
  end

  def encode_command(_model, %Command{type: :conversation_item_create, data: item}, _opts)
      when is_map(item) do
    %{event: "conversation.message", payload: item}
  end

  def encode_command(_model, %Command{type: :input_audio_append, data: audio}, _opts)
      when is_binary(audio) do
    %{event: "audio.append", payload: Base.encode64(audio)}
  end

  def encode_command(_model, %Command{type: :input_audio_commit}, _opts) do
    %{event: "audio.commit"}
  end

  def encode_command(_model, %Command{type: :response_create, data: data}, _opts)
      when is_map(data) do
    %{event: "response.begin", payload: data}
  end

  def encode_command(_model, %Command{type: :response_cancel}, _opts) do
    %{event: "response.stop"}
  end

  @impl ReqLlmNext.Realtime.Adapter
  def decode_event(%{"kind" => "text", "text" => text}, _model, _opts) when is_binary(text) do
    [Event.text_delta(text)]
  end

  def decode_event(%{"kind" => "reasoning", "text" => text}, _model, _opts)
      when is_binary(text) do
    [Event.thinking_delta(text)]
  end

  def decode_event(%{"kind" => "media.audio", "chunk" => chunk}, _model, _opts)
      when is_binary(chunk) do
    [Event.audio_delta(chunk)]
  end

  def decode_event(%{"kind" => "tool", "index" => index, "name" => name}, _model, _opts)
      when is_integer(index) and is_binary(name) do
    [Event.tool_call_start(%{index: index, id: "tool_#{index}", name: name})]
  end

  def decode_event(
        %{"kind" => "tool.delta", "index" => index, "arguments" => arguments},
        _model,
        _opts
      )
      when is_integer(index) and is_binary(arguments) do
    [Event.tool_call_delta(%{index: index, function: %{"arguments" => arguments}})]
  end

  def decode_event(%{"kind" => "done", "id" => response_id}, _model, _opts)
      when is_binary(response_id) do
    [Event.meta(%{terminal?: true, finish_reason: :stop, response_id: response_id})]
  end

  def decode_event(%{"kind" => "other"} = event, _model, _opts) do
    [Event.provider_event(event)]
  end

  def decode_event(_event, _model, _opts), do: []

  @impl ReqLlmNext.Realtime.Adapter
  def websocket_url(model, _opts) do
    "realtime://fake.example/sessions/#{model.id}"
  end
end
