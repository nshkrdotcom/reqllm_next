defmodule ReqLlmNext.Wire.XAIResponses do
  @moduledoc """
  xAI Responses wire built on the OpenAI-compatible Responses request shape.
  """

  @behaviour ReqLlmNext.Wire.Streaming

  alias ReqLlmNext.Wire.OpenAIResponses
  alias ReqLlmNext.XAI.Tools, as: XAITools
  alias ReqLlmNext.Tool

  @impl ReqLlmNext.Wire.Streaming
  def endpoint, do: OpenAIResponses.endpoint()

  @spec path() :: String.t()
  def path, do: OpenAIResponses.path()

  @impl ReqLlmNext.Wire.Streaming
  def encode_body(model, prompt, opts) do
    build_request_body(model, prompt, opts)
    |> Map.put(:stream, true)
  end

  @spec build_request_body(LLMDB.Model.t(), String.t() | ReqLlmNext.Context.t(), keyword()) ::
          map()
  def build_request_body(model, prompt, opts) do
    tools = Keyword.get(opts, :tools, [])

    model
    |> OpenAIResponses.build_request_body(prompt, Keyword.put(opts, :tools, []))
    |> maybe_add_tools(tools)
  end

  @impl ReqLlmNext.Wire.Streaming
  def options_schema do
    OpenAIResponses.options_schema() ++
      [
        xai_tools: [type: {:list, :map}, doc: "xAI built-in tools configuration"]
      ]
  end

  @impl ReqLlmNext.Wire.Streaming
  def decode_wire_event(event), do: OpenAIResponses.decode_wire_event(event)

  @spec decode_sse_event(map(), LLMDB.Model.t() | nil) :: [term()]
  def decode_sse_event(event, model) do
    event
    |> decode_wire_event()
    |> Enum.flat_map(&ReqLlmNext.SemanticProtocols.XAIResponses.decode_event(&1, model))
  end

  defp maybe_add_tools(body, []), do: body

  defp maybe_add_tools(body, tools),
    do: Map.put(body, :tools, Enum.map(tools, &encode_tool_def/1))

  defp encode_tool_def(%Tool{} = tool), do: encode_responses_tool(tool)

  defp encode_tool_def(tool) when is_map(tool) do
    case XAITools.encode_provider_native_tool(tool) do
      {:ok, encoded_tool} ->
        encoded_tool

      :error ->
        raise ArgumentError,
              "xAI Responses surfaces require ReqLlmNext.Tool values or ReqLlmNext.XAI.Tools helper maps"
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
end
