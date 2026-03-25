defmodule ReqLlmNext.ModelProfile.ProviderFacts.XAI do
  @moduledoc """
  xAI-specific descriptive fact extraction.
  """

  @spec extract(LLMDB.Model.t()) :: ReqLlmNext.ModelProfile.ProviderFacts.extracted_patch()
  def extract(%LLMDB.Model{} = model) do
    media_api = media_api(model)

    %{
      responses_api?: media_api == nil,
      structured_outputs_native?: media_api == nil and supports_native_structured_outputs?(model),
      citations_supported?: true,
      context_management_supported?: false,
      media_api: media_api,
      image_generation_supported?: media_api == :images,
      chat_supported?: chat_supported_override(media_api)
    }
  end

  @spec media_api(LLMDB.Model.t()) :: :images | nil
  def media_api(%LLMDB.Model{} = model) do
    api = get_in(model, [Access.key(:extra, %{}), :api])
    model_id = model.id || ""
    output_modalities = get_in(model, [Access.key(:modalities, %{}), :output]) || []

    cond do
      api == "images" ->
        :images

      :image in output_modalities and String.contains?(model_id, "imagine") ->
        :images

      String.starts_with?(model_id, "grok-imagine") ->
        :images

      true ->
        nil
    end
  end

  @spec supports_native_structured_outputs?(LLMDB.Model.t() | binary()) :: boolean()
  def supports_native_structured_outputs?(%LLMDB.Model{} = model) do
    case get_in(model, [Access.key(:capabilities, %{}), :native_json_schema]) do
      nil -> supports_native_structured_outputs?(model.id || "")
      value -> value
    end
  end

  def supports_native_structured_outputs?(model_id) when is_binary(model_id) do
    cond do
      model_id in ["grok-2", "grok-2-vision"] ->
        false

      String.starts_with?(model_id, "grok-2-") or
          String.starts_with?(model_id, "grok-2-vision-") ->
        suffix =
          cond do
            String.starts_with?(model_id, "grok-2-vision-") ->
              String.replace_prefix(model_id, "grok-2-vision-", "")

            String.starts_with?(model_id, "grok-2-") ->
              String.replace_prefix(model_id, "grok-2-", "")

            true ->
              ""
          end

        suffix >= "1212"

      true ->
        true
    end
  end

  defp chat_supported_override(:images), do: false
  defp chat_supported_override(_media_api), do: nil
end
