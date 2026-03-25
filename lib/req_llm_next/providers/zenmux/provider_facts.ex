defmodule ReqLlmNext.ModelProfile.ProviderFacts.Zenmux do
  @moduledoc """
  Zenmux-specific descriptive fact extraction.
  """

  @chat_apis ["chat", "chat_completions", "chat-completions"]
  @responses_apis ["responses", "response"]

  @spec extract(LLMDB.Model.t()) :: ReqLlmNext.ModelProfile.ProviderFacts.extracted_patch()
  def extract(%LLMDB.Model{} = model) do
    %{
      responses_api?: responses_api?(model),
      structured_outputs_native?: true,
      citations_supported?: true,
      context_management_supported?: false,
      media_api: nil
    }
  end

  @spec responses_api?(LLMDB.Model.t()) :: boolean()
  def responses_api?(%LLMDB.Model{} = model) do
    extra = Map.get(model, :extra, %{}) || %{}
    api = Map.get(extra, :api) || Map.get(extra, "api")
    wire = Map.get(extra, :wire) || Map.get(extra, "wire") || %{}
    protocol = Map.get(wire, :protocol) || Map.get(wire, "protocol")

    cond do
      api in @chat_apis ->
        false

      protocol in [:openai_chat, "openai_chat", :chat, "chat"] ->
        false

      api in @responses_apis ->
        true

      protocol in [:openai_responses, "openai_responses", :responses, "responses"] ->
        true

      true ->
        true
    end
  end
end
