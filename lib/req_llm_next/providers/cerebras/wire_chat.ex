defmodule ReqLlmNext.Wire.CerebrasChat do
  @moduledoc """
  Cerebras chat-completions wire built on the OpenAI-compatible happy path.
  """

  @behaviour ReqLlmNext.Wire.Streaming

  alias ReqLlmNext.ModelHelpers
  alias ReqLlmNext.Wire.OpenAIChat

  @impl ReqLlmNext.Wire.Streaming
  def endpoint, do: OpenAIChat.endpoint()

  @impl ReqLlmNext.Wire.Streaming
  def encode_body(model, prompt, opts) do
    model
    |> OpenAIChat.encode_body(prompt, opts)
    |> add_strict_to_tools(model)
    |> normalize_assistant_content()
  end

  @impl ReqLlmNext.Wire.Streaming
  def options_schema, do: OpenAIChat.options_schema()

  @impl ReqLlmNext.Wire.Streaming
  def decode_wire_event(event), do: OpenAIChat.decode_wire_event(event)

  @spec decode_sse_event(map(), LLMDB.Model.t() | nil) :: [term()]
  def decode_sse_event(event, model), do: OpenAIChat.decode_sse_event(event, model)

  defp add_strict_to_tools(%{tools: tools} = body, %LLMDB.Model{} = model) when is_list(tools) do
    updated =
      if ModelHelpers.tools_strict?(model) do
        Enum.map(tools, &put_strict_in_tool/1)
      else
        Enum.map(tools, &strip_unsupported_schema_constraints/1)
      end

    Map.put(body, :tools, updated)
  end

  defp add_strict_to_tools(body, _model), do: body

  defp put_strict_in_tool(%{function: function} = tool) when is_map(function) do
    Map.put(tool, :function, Map.put(function, :strict, true))
  end

  defp put_strict_in_tool(%{"function" => function} = tool) when is_map(function) do
    Map.put(tool, "function", Map.put(function, "strict", true))
  end

  defp put_strict_in_tool(tool), do: tool

  defp strip_unsupported_schema_constraints(%{function: function} = tool) when is_map(function) do
    parameters = Map.get(function, :parameters)

    normalized =
      if is_map(parameters) do
        Map.put(function, :parameters, strip_constraints_recursive(parameters))
      else
        function
      end

    Map.put(tool, :function, normalized)
  end

  defp strip_unsupported_schema_constraints(%{"function" => function} = tool)
       when is_map(function) do
    parameters = Map.get(function, "parameters")

    normalized =
      if is_map(parameters) do
        Map.put(function, "parameters", strip_constraints_recursive(parameters))
      else
        function
      end

    Map.put(tool, "function", normalized)
  end

  defp strip_unsupported_schema_constraints(tool), do: tool

  defp strip_constraints_recursive(schema) when is_map(schema) do
    schema
    |> Map.drop(["minimum", "maximum", "minLength", "maxLength"])
    |> Map.drop([:minimum, :maximum, :minLength, :maxLength])
    |> Enum.map(fn
      {key, value} when is_map(value) ->
        {key, strip_constraints_recursive(value)}

      {"properties", value} when is_map(value) ->
        {"properties",
         Map.new(value, fn {prop, prop_schema} ->
           {prop, strip_constraints_recursive(prop_schema)}
         end)}

      {:properties, value} when is_map(value) ->
        {:properties,
         Map.new(value, fn {prop, prop_schema} ->
           {prop, strip_constraints_recursive(prop_schema)}
         end)}

      pair ->
        pair
    end)
    |> Map.new()
  end

  defp strip_constraints_recursive(value), do: value

  defp normalize_assistant_content(%{messages: messages} = body) when is_list(messages) do
    Map.put(body, :messages, Enum.map(messages, &normalize_assistant_message/1))
  end

  defp normalize_assistant_message(%{role: "assistant", content: []} = message) do
    Map.put(message, :content, "")
  end

  defp normalize_assistant_message(message), do: message
end
