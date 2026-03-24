defmodule ReqLlmNext.Response.Materializer do
  @moduledoc false

  alias ReqLlmNext.Context
  alias ReqLlmNext.Context.{ContentPart, Message}
  alias ReqLlmNext.Response

  defstruct content_parts: [],
            tool_acc: %{},
            usage: nil,
            meta: %{}

  @type t :: %__MODULE__{
          content_parts: [ContentPart.t()],
          tool_acc: map(),
          usage: map() | nil,
          meta: map()
        }

  @spec collect(Enumerable.t()) :: {:ok, t()} | {:error, term()}
  def collect(stream) do
    stream
    |> Enum.reduce_while({:ok, new()}, &consume_chunk/2)
    |> case do
      {:ok, %__MODULE__{} = materialized} ->
        {:ok, finalize(materialized)}

      {:error, _} = error ->
        error
    end
  end

  @spec text(t()) :: String.t()
  def text(%__MODULE__{content_parts: content_parts}) do
    content_parts
    |> Enum.filter(&(&1.type == :text))
    |> Enum.map_join("", & &1.text)
  end

  @spec thinking(t()) :: String.t()
  def thinking(%__MODULE__{content_parts: content_parts}) do
    content_parts
    |> Enum.filter(&(&1.type == :thinking))
    |> Enum.map_join("", & &1.text)
  end

  @spec tool_calls(t()) :: [ReqLlmNext.ToolCall.t()]
  def tool_calls(%__MODULE__{tool_acc: tool_acc}) do
    tool_acc
    |> Map.values()
    |> Enum.sort_by(& &1.index)
    |> Enum.map(&finalize_tool_call/1)
  end

  @spec usage(t()) :: map() | nil
  def usage(%__MODULE__{usage: usage}), do: usage

  @spec finish_reason(t()) :: atom() | nil
  def finish_reason(%__MODULE__{meta: meta}), do: meta[:finish_reason]

  @spec provider_meta(t()) :: map()
  def provider_meta(%__MODULE__{meta: meta}) when is_map(meta) do
    meta
    |> Map.drop([:terminal?, :finish_reason])
    |> Enum.into(%{})
  end

  @spec assistant_message(t()) :: Message.t() | nil
  def assistant_message(%__MODULE__{} = materialized) do
    content_parts = materialized.content_parts
    tool_calls = tool_calls(materialized)

    if content_parts != [] or tool_calls != [] do
      %Message{
        role: :assistant,
        content: content_parts,
        tool_calls: if(tool_calls == [], do: nil, else: tool_calls)
      }
    else
      nil
    end
  end

  @spec response(Response.t(), t()) :: Response.t()
  def response(%Response{} = response, %__MODULE__{} = materialized) do
    message = assistant_message(materialized)

    updated_context =
      if message do
        Context.append(response.context, message)
      else
        response.context
      end

    %{
      response
      | stream?: false,
        stream: nil,
        message: message,
        context: updated_context,
        usage: usage(materialized) || response.usage,
        finish_reason: finish_reason(materialized) || response.finish_reason,
        provider_meta: Map.merge(response.provider_meta || %{}, provider_meta(materialized))
    }
  end

  defp new do
    %__MODULE__{}
  end

  defp finalize(%__MODULE__{} = materialized) do
    %{materialized | content_parts: Enum.reverse(materialized.content_parts)}
  end

  defp consume_chunk({:error, error_info}, {:ok, _materialized}) do
    error =
      ReqLlmNext.Error.API.Stream.exception(
        reason: error_info.message,
        cause: error_info
      )

    {:halt, {:error, error}}
  end

  defp consume_chunk(text, {:ok, %__MODULE__{} = materialized}) when is_binary(text) do
    {:cont, {:ok, add_content_part(materialized, ContentPart.text(text))}}
  end

  defp consume_chunk({:thinking, text}, {:ok, %__MODULE__{} = materialized})
       when is_binary(text) do
    {:cont, {:ok, add_content_part(materialized, ContentPart.thinking(text))}}
  end

  defp consume_chunk({:content_part, %ContentPart{} = part}, {:ok, %__MODULE__{} = materialized}) do
    {:cont, {:ok, add_content_part(materialized, part)}}
  end

  defp consume_chunk({:usage, usage_map}, {:ok, %__MODULE__{} = materialized}) do
    {:cont, {:ok, %{materialized | usage: usage_map}}}
  end

  defp consume_chunk(
         {:tool_call_delta, %{index: index} = delta},
         {:ok, %__MODULE__{} = materialized}
       ) do
    tool_acc =
      Map.update(materialized.tool_acc, index, init_tool_call(delta), &merge_tool_call(&1, delta))

    {:cont, {:ok, %{materialized | tool_acc: tool_acc}}}
  end

  defp consume_chunk(
         {:tool_call_start, %{index: index} = start},
         {:ok, %__MODULE__{} = materialized}
       ) do
    tool_acc =
      Map.update(
        materialized.tool_acc,
        index,
        init_tool_call_from_start(start),
        &merge_start(&1, start)
      )

    {:cont, {:ok, %{materialized | tool_acc: tool_acc}}}
  end

  defp consume_chunk({:meta, meta_chunk}, {:ok, %__MODULE__{} = materialized})
       when is_map(meta_chunk) do
    {:cont, {:ok, %{materialized | meta: Map.merge(materialized.meta, meta_chunk)}}}
  end

  defp consume_chunk(_other, {:ok, %__MODULE__{} = materialized}) do
    {:cont, {:ok, materialized}}
  end

  defp add_content_part(%__MODULE__{} = materialized, %ContentPart{} = part) do
    %{materialized | content_parts: [part | materialized.content_parts]}
  end

  defp init_tool_call(%{id: id, function: function} = delta) when not is_nil(id) do
    %{
      index: delta.index,
      id: id,
      type: delta[:type] || "function",
      name: function["name"],
      arguments: function["arguments"] || ""
    }
  end

  defp init_tool_call(delta) do
    %{
      index: delta.index,
      id: nil,
      type: delta[:type],
      name: delta[:function]["name"],
      arguments: delta[:function]["arguments"] || ""
    }
  end

  defp init_tool_call_from_start(%{index: index, id: id, name: name}) do
    %{
      index: index,
      id: id,
      type: "function",
      name: name,
      arguments: ""
    }
  end

  defp merge_tool_call(acc, %{function: function}) when is_map(function) do
    %{
      acc
      | name: acc.name || function["name"],
        arguments: acc.arguments <> (function["arguments"] || "")
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

  defp finalize_tool_call(%{id: id, name: name, arguments: args}) do
    ReqLlmNext.ToolCall.new(id, name, args)
  end
end
