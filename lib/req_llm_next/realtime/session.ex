defmodule ReqLlmNext.Realtime.Session do
  @moduledoc """
  Canonical realtime session state reducer.
  """

  alias ReqLlmNext.Response.OutputItem
  alias ReqLlmNext.Realtime.Event

  @schema Zoi.struct(
            __MODULE__,
            %{
              model: Zoi.any() |> Zoi.nullish() |> Zoi.default(nil),
              output_items: Zoi.array(Zoi.any()) |> Zoi.default([]),
              tool_acc: Zoi.map() |> Zoi.default(%{}),
              usage: Zoi.map() |> Zoi.nullish() |> Zoi.default(nil),
              finish_reason: Zoi.atom() |> Zoi.nullish() |> Zoi.default(nil),
              response_id: Zoi.string() |> Zoi.nullish() |> Zoi.default(nil),
              provider_meta: Zoi.map() |> Zoi.default(%{})
            },
            coerce: true
          )

  @type t :: %__MODULE__{
          model: LLMDB.Model.t() | nil,
          output_items: [OutputItem.t()],
          tool_acc: map(),
          usage: map() | nil,
          finish_reason: atom() | nil,
          response_id: String.t() | nil,
          provider_meta: map()
        }

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs) do
    Zoi.parse(@schema, attrs)
  end

  @spec new!(map()) :: t()
  def new!(attrs) when is_map(attrs) do
    case new(attrs) do
      {:ok, session} -> session
      {:error, reason} -> raise ArgumentError, "Invalid realtime session: #{inspect(reason)}"
    end
  end

  @spec apply_event(t(), Event.t()) :: t()
  def apply_event(%__MODULE__{} = session, %Event{
        type: :text_delta,
        data: text,
        metadata: metadata
      })
      when is_binary(text) do
    add_output_item(session, OutputItem.text(text, metadata))
  end

  def apply_event(
        %__MODULE__{} = session,
        %Event{type: :thinking_delta, data: text, metadata: metadata}
      )
      when is_binary(text) do
    add_output_item(session, OutputItem.thinking(text, metadata))
  end

  def apply_event(
        %__MODULE__{} = session,
        %Event{type: :audio_delta, data: data, metadata: metadata}
      )
      when is_binary(data) do
    add_output_item(session, OutputItem.audio(data, metadata))
  end

  def apply_event(
        %__MODULE__{} = session,
        %Event{type: :transcript_delta, data: text, metadata: metadata}
      )
      when is_binary(text) do
    add_output_item(session, OutputItem.transcript(text, metadata))
  end

  def apply_event(
        %__MODULE__{} = session,
        %Event{type: :provider_event, data: event}
      )
      when is_map(event) do
    add_output_item(session, OutputItem.provider_item(event))
  end

  def apply_event(
        %__MODULE__{} = session,
        %Event{type: :tool_call_start, data: %{index: index} = data}
      ) do
    tool_acc =
      Map.update(
        session.tool_acc,
        index,
        init_tool_call_from_start(data),
        &merge_start(&1, data)
      )

    %{session | tool_acc: tool_acc}
  end

  def apply_event(
        %__MODULE__{} = session,
        %Event{type: :tool_call_delta, data: %{index: index} = data}
      ) do
    tool_acc =
      Map.update(session.tool_acc, index, init_tool_call(data), &merge_tool_call(&1, data))

    %{session | tool_acc: tool_acc}
  end

  def apply_event(%__MODULE__{} = session, %Event{type: :usage, data: usage})
      when is_map(usage) do
    %{session | usage: usage}
  end

  def apply_event(%__MODULE__{} = session, %Event{type: :meta, data: meta}) when is_map(meta) do
    %{
      session
      | finish_reason: Map.get(meta, :finish_reason, session.finish_reason),
        response_id: Map.get(meta, :response_id, session.response_id),
        provider_meta: Map.merge(session.provider_meta, meta)
    }
  end

  def apply_event(%__MODULE__{} = session, %Event{type: :error, data: error})
      when is_map(error) do
    %{
      session
      | finish_reason: :error,
        provider_meta: Map.merge(session.provider_meta, %{error: error})
    }
  end

  def apply_event(%__MODULE__{} = session, %Event{}), do: session

  @spec apply_events(t(), [Event.t()]) :: t()
  def apply_events(%__MODULE__{} = session, events) when is_list(events) do
    Enum.reduce(events, session, &apply_event(&2, &1))
  end

  @spec output_items(t()) :: [OutputItem.t()]
  def output_items(%__MODULE__{output_items: output_items} = session) do
    output_items
    |> Enum.reverse()
    |> Kernel.++(Enum.map(tool_calls(session), &OutputItem.tool_call/1))
  end

  @spec text(t()) :: String.t()
  def text(%__MODULE__{} = session) do
    session
    |> output_items()
    |> Enum.flat_map(fn
      %OutputItem{type: :text, data: text} when is_binary(text) -> [text]
      _ -> []
    end)
    |> Enum.join("")
  end

  @spec thinking(t()) :: String.t()
  def thinking(%__MODULE__{} = session) do
    session
    |> output_items()
    |> Enum.flat_map(fn
      %OutputItem{type: :thinking, data: text} when is_binary(text) -> [text]
      _ -> []
    end)
    |> Enum.join("")
  end

  @spec transcripts(t()) :: [String.t()]
  def transcripts(%__MODULE__{} = session) do
    session
    |> output_items()
    |> Enum.flat_map(fn
      %OutputItem{type: :transcript, data: text} when is_binary(text) -> [text]
      _ -> []
    end)
  end

  @spec audio_chunks(t()) :: [binary()]
  def audio_chunks(%__MODULE__{} = session) do
    session
    |> output_items()
    |> Enum.flat_map(fn
      %OutputItem{type: :audio, data: data} when is_binary(data) -> [data]
      _ -> []
    end)
  end

  @spec tool_calls(t()) :: [ReqLlmNext.ToolCall.t()]
  def tool_calls(%__MODULE__{tool_acc: tool_acc}) do
    tool_acc
    |> Map.values()
    |> Enum.sort_by(& &1.index)
    |> Enum.map(&ReqLlmNext.ToolCall.new(&1.id, &1.name, &1.arguments))
  end

  defp add_output_item(%__MODULE__{} = session, %OutputItem{} = item) do
    %{session | output_items: [item | session.output_items]}
  end

  defp init_tool_call(%{index: index} = delta) do
    %{
      index: index,
      id: Map.get(delta, :id),
      name:
        get_in(delta, [:function, "name"]) || get_in(delta, [:function, :name]) ||
          Map.get(delta, :name),
      arguments:
        get_in(delta, [:function, "arguments"]) || get_in(delta, [:function, :arguments]) ||
          Map.get(delta, :partial_json, "")
    }
  end

  defp init_tool_call_from_start(%{index: index, id: id, name: name}) do
    %{index: index, id: id, name: name, arguments: ""}
  end

  defp merge_tool_call(acc, %{function: function}) when is_map(function) do
    %{
      acc
      | name: acc.name || function["name"] || function[:name],
        arguments: acc.arguments <> (function["arguments"] || function[:arguments] || "")
    }
  end

  defp merge_tool_call(acc, %{partial_json: json}) when is_binary(json) do
    %{acc | arguments: acc.arguments <> json}
  end

  defp merge_tool_call(acc, %{id: id}) when not is_nil(id) do
    %{acc | id: id}
  end

  defp merge_tool_call(acc, _delta), do: acc

  defp merge_start(acc, %{id: id, name: name}) do
    %{acc | id: id || acc.id, name: name || acc.name}
  end
end
