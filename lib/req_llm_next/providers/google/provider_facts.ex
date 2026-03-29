defmodule ReqLlmNext.ModelProfile.ProviderFacts.Google do
  @moduledoc """
  Google Gemini-specific descriptive fact extraction.
  """

  defp output_modalities(%LLMDB.Model{modalities: modalities}) when is_map(modalities) do
    Map.get(modalities, :output, [])
  end

  defp output_modalities(_model), do: []

  defp embedding_model?(%LLMDB.Model{} = model) do
    output_modalities(model)
    |> Enum.member?(:embedding)
  end

  defp non_chat_model_id?(id) when is_binary(id) do
    String.contains?(id, "imagen") or
      String.contains?(id, "banana") or
      String.contains?(id, "veo") or
      String.contains?(id, "lyria")
  end

  defp chat_model_id?(id) when is_binary(id) do
    String.starts_with?(id, "gemini") or id == "aqa"
  end

  defp image_generation_model?(%LLMDB.Model{id: id} = model) when is_binary(id) do
    Enum.member?(output_modalities(model), :image) or
      String.contains?(id, "imagen") or
      String.contains?(id, "banana") or
      String.contains?(id, "flash-image") or
      String.contains?(id, "pro-image-preview")
  end

  defp image_only_model?(%LLMDB.Model{id: id} = model) when is_binary(id) do
    outputs = output_modalities(model)

    image_generation_model?(model) and
      (:text not in outputs or
         String.contains?(id, "imagen") or
         String.contains?(id, "banana") or
         String.contains?(id, "flash-image") or
         String.contains?(id, "pro-image-preview"))
  end

  @spec extract(LLMDB.Model.t()) :: ReqLlmNext.ModelProfile.ProviderFacts.extracted_patch()
  def extract(%LLMDB.Model{} = model) do
    %{
      responses_api?: false,
      structured_outputs_native?: true,
      citations_supported?: true,
      context_management_supported?: false,
      media_api: if(image_only_model?(model), do: :images, else: nil),
      image_generation_supported?: image_generation_model?(model),
      chat_supported?:
        cond do
          embedding_model?(model) -> false
          image_only_model?(model) -> false
          non_chat_model_id?(model.id) -> false
          chat_model_id?(model.id) -> true
          true -> nil
        end
    }
  end
end
