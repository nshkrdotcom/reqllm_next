defmodule ReqLlmNext.ExecutionModules do
  @moduledoc """
  Resolves the runtime modules for a planned execution stack.
  """

  alias ReqLlmNext.{ExecutionPlan, Providers, SemanticProtocols, Transports, Wire}

  @type resolution :: %{
          provider_mod: module(),
          protocol_mod: module() | nil,
          wire_mod: module(),
          transport_mod: module() | nil
        }

  @spec resolve(ExecutionPlan.t()) :: resolution()
  def resolve(%ExecutionPlan{} = plan) do
    %{
      provider_mod: Providers.get!(plan.provider),
      protocol_mod: protocol_module!(plan.semantic_protocol),
      wire_mod: wire_module!(plan.wire_format),
      transport_mod: transport_module!(plan.transport, plan.wire_format)
    }
  end

  @spec protocol_module!(atom()) :: module() | nil
  def protocol_module!(:anthropic_messages), do: SemanticProtocols.AnthropicMessages
  def protocol_module!(:openai_chat), do: SemanticProtocols.OpenAIChat
  def protocol_module!(:openai_responses), do: SemanticProtocols.OpenAIResponses
  def protocol_module!(:openai_embeddings), do: nil
  def protocol_module!(other), do: raise("Unknown semantic protocol: #{inspect(other)}")

  @spec wire_module!(atom()) :: module()
  def wire_module!(:anthropic_messages_sse_json), do: Wire.Anthropic
  def wire_module!(:openai_chat_sse_json), do: Wire.OpenAIChat
  def wire_module!(:openai_responses_sse_json), do: Wire.OpenAIResponses
  def wire_module!(:openai_responses_ws_json), do: Wire.OpenAIResponses
  def wire_module!(:openai_embeddings_json), do: Wire.OpenAIEmbeddings
  def wire_module!(other), do: raise("Unknown wire format: #{inspect(other)}")

  @spec transport_module!(atom(), atom()) :: module() | nil
  def transport_module!(:http, _wire_format), do: nil
  def transport_module!(:http_sse, _wire_format), do: Transports.HTTPStream

  def transport_module!(:websocket, :openai_responses_ws_json),
    do: Transports.OpenAIResponsesWebSocket

  def transport_module!(transport, wire_format) do
    raise("Unknown transport/wire format combination: #{inspect({transport, wire_format})}")
  end
end
