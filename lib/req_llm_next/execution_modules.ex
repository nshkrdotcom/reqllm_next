defmodule ReqLlmNext.ExecutionModules do
  @moduledoc """
  Transitional bridge from execution plans to the current provider and wire modules.
  """

  alias ReqLlmNext.{ExecutionPlan, Providers, Wire}

  @type resolution :: %{provider_mod: module(), wire_mod: module()}

  @spec resolve(ExecutionPlan.t()) :: resolution()
  def resolve(%ExecutionPlan{} = plan) do
    %{
      provider_mod: Providers.get!(plan.provider),
      wire_mod: wire_module!(plan.wire_format)
    }
  end

  defp wire_module!(:anthropic_messages_sse_json), do: Wire.Anthropic
  defp wire_module!(:openai_chat_sse_json), do: Wire.OpenAIChat
  defp wire_module!(:openai_responses_sse_json), do: Wire.OpenAIResponses
  defp wire_module!(:openai_embeddings_json), do: Wire.OpenAIEmbeddings
  defp wire_module!(other), do: raise("Unknown wire format: #{inspect(other)}")
end
