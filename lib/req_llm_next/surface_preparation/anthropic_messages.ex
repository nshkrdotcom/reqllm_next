defmodule ReqLlmNext.SurfacePreparation.AnthropicMessages do
  @moduledoc """
  Anthropic Messages surface-owned request preparation.
  """

  alias ReqLlmNext.Context
  alias ReqLlmNext.Context.ContentPart
  alias ReqLlmNext.ExecutionSurface

  @spec prepare(ExecutionSurface.t(), term(), keyword()) :: {:ok, keyword()}
  def prepare(%ExecutionSurface{}, prompt, opts) do
    {:ok, maybe_enable_files_api(prompt, opts)}
  end

  defp maybe_enable_files_api(%Context{messages: messages}, opts) do
    if Keyword.has_key?(opts, :anthropic_files_api) do
      opts
    else
      Keyword.put(opts, :anthropic_files_api, context_uses_files_api?(messages))
    end
  end

  defp maybe_enable_files_api(_prompt, opts), do: opts

  defp context_uses_files_api?(messages) when is_list(messages) do
    Enum.any?(messages, fn message ->
      Enum.any?(message.content || [], &files_api_part?/1)
    end)
  end

  defp files_api_part?(%ContentPart{type: :document}), do: true

  defp files_api_part?(%ContentPart{type: :file, metadata: metadata}) do
    type = Map.get(metadata || %{}, :anthropic_type) || Map.get(metadata || %{}, "anthropic_type")
    source = Map.get(metadata || %{}, :source_type) || Map.get(metadata || %{}, "source_type")
    type in [:container_upload, "container_upload"] or source in [:file_id, "file_id"]
  end

  defp files_api_part?(_part), do: false
end
