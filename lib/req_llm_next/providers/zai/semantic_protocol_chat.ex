defmodule ReqLlmNext.SemanticProtocols.ZAIChat do
  @moduledoc false

  @behaviour ReqLlmNext.SemanticProtocol

  alias ReqLlmNext.SemanticProtocols.DeepSeekChat

  @impl ReqLlmNext.SemanticProtocol
  def decode_event(event, model), do: DeepSeekChat.decode_event(event, model)
end
