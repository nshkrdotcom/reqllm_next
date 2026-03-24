defmodule ReqLlmNext.Families.OpenAICompatible.FileInput do
  @moduledoc """
  Shared OpenAI-compatible file input encoding.
  """

  alias ReqLlmNext.Context.ContentPart

  @spec encode(ContentPart.t()) :: map()
  def encode(%ContentPart{} = part) do
    case source(part) do
      {:file_id, file_id} ->
        %{file_id: file_id}

      {:file_url, file_url} ->
        %{file_url: file_url}

      {:inline, data, media_type} ->
        %{
          filename: filename(part, media_type),
          file_data: data_uri(data, media_type)
        }
    end
  end

  defp source(%ContentPart{type: type, metadata: metadata, data: data, media_type: media_type})
       when is_binary(data) do
    case source_type(metadata) do
      :file_id ->
        {:file_id, data}

      _ ->
        source_from_binary(data, metadata, media_type || "application/octet-stream", type)
    end
  end

  defp source(%ContentPart{url: url}) when is_binary(url), do: {:file_url, url}

  defp source(%ContentPart{data: data, media_type: media_type}) when is_binary(data) do
    {:inline, data, media_type || "application/octet-stream"}
  end

  defp source(%ContentPart{media_type: media_type}) do
    {:inline, <<>>, media_type || "application/octet-stream"}
  end

  defp source_from_binary("file-" <> _rest = file_id, _metadata, _media_type, :document),
    do: {:file_id, file_id}

  defp source_from_binary("file_" <> _rest = file_id, _metadata, _media_type, :document),
    do: {:file_id, file_id}

  defp source_from_binary(data, _metadata, media_type, _type), do: {:inline, data, media_type}

  defp source_type(metadata) when is_map(metadata) do
    metadata
    |> Map.get(:source_type, Map.get(metadata, "source_type"))
    |> normalize_source_type()
  end

  defp source_type(_), do: nil

  defp normalize_source_type(:file_id), do: :file_id
  defp normalize_source_type("file_id"), do: :file_id
  defp normalize_source_type(:file_url), do: :file_url
  defp normalize_source_type("file_url"), do: :file_url
  defp normalize_source_type(_), do: nil

  defp filename(%ContentPart{filename: filename}, _media_type) when is_binary(filename),
    do: filename

  defp filename(%ContentPart{metadata: metadata}, media_type) do
    case metadata do
      %{title: title} when is_binary(title) -> title
      %{"title" => title} when is_binary(title) -> title
      _ -> default_filename(media_type)
    end
  end

  defp default_filename("application/pdf"), do: "document.pdf"
  defp default_filename("text/plain"), do: "document.txt"
  defp default_filename("text/csv"), do: "data.csv"
  defp default_filename("application/csv"), do: "data.csv"
  defp default_filename("application/json"), do: "document.json"
  defp default_filename(_), do: "attachment.bin"

  defp data_uri(data, media_type) do
    "data:#{media_type};base64,#{Base.encode64(data)}"
  end
end
