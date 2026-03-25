defmodule ReqLlmNext.Transcription.AudioInput do
  @moduledoc false

  alias ReqLlmNext.Error

  @type t :: %{data: binary(), media_type: String.t(), filename: String.t()}

  @spec resolve(String.t() | {:binary, binary(), String.t()} | {:base64, String.t(), String.t()}) ::
          {:ok, t()} | {:error, term()}
  def resolve(path) when is_binary(path) do
    case File.read(path) do
      {:ok, data} ->
        {:ok,
         %{
           data: data,
           media_type: media_type_from_path(path),
           filename: Path.basename(path)
         }}

      {:error, reason} ->
        {:error,
         Error.Invalid.Parameter.exception(
           parameter: "audio: could not read file #{path} (#{reason})"
         )}
    end
  end

  def resolve({:binary, data, media_type})
      when is_binary(data) and is_binary(media_type) do
    {:ok,
     %{
       data: data,
       media_type: media_type,
       filename: "audio.#{extension_for(media_type)}"
     }}
  end

  def resolve({:base64, encoded, media_type})
      when is_binary(encoded) and is_binary(media_type) do
    case Base.decode64(encoded) do
      {:ok, data} ->
        resolve({:binary, data, media_type})

      :error ->
        {:error, Error.Invalid.Parameter.exception(parameter: "audio: invalid base64 encoding")}
    end
  end

  def resolve(other) do
    {:error,
     Error.Invalid.Parameter.exception(
       parameter:
         "audio: expected a file path string, {:binary, data, media_type}, or {:base64, data, media_type}, got: #{inspect(other)}"
     )}
  end

  @media_types %{
    ".mp3" => "audio/mpeg",
    ".mp4" => "audio/mp4",
    ".mpeg" => "audio/mpeg",
    ".mpga" => "audio/mpeg",
    ".m4a" => "audio/mp4",
    ".wav" => "audio/wav",
    ".webm" => "audio/webm",
    ".ogg" => "audio/ogg",
    ".flac" => "audio/flac",
    ".opus" => "audio/opus"
  }

  @extensions %{
    "audio/mpeg" => "mp3",
    "audio/mp4" => "mp4",
    "audio/wav" => "wav",
    "audio/webm" => "webm",
    "audio/ogg" => "ogg",
    "audio/flac" => "flac",
    "audio/opus" => "opus"
  }

  defp media_type_from_path(path) do
    path
    |> Path.extname()
    |> String.downcase()
    |> then(&Map.get(@media_types, &1, "application/octet-stream"))
  end

  defp extension_for(media_type) do
    Map.get(@extensions, media_type, "bin")
  end
end
