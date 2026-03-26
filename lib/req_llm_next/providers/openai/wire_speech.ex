defmodule ReqLlmNext.Wire.OpenAISpeech do
  @moduledoc """
  OpenAI Audio Speech API wire.
  """

  alias ReqLlmNext.Error
  alias ReqLlmNext.Provider
  alias ReqLlmNext.Speech

  @spec path() :: String.t()
  def path, do: "/v1/audio/speech"

  @spec build_request(module(), LLMDB.Model.t(), String.t(), keyword()) ::
          {:ok, Finch.Request.t()} | {:error, term()}
  def build_request(provider_mod, model, text, opts) when is_binary(text) do
    prepared_text = Keyword.get(opts, :_prepared_text, text)

    with {:ok, url} <-
           Provider.request_url(provider_mod, model, path(), Keyword.put(opts, :path, path())),
         {:ok, headers} <-
           Provider.request_headers(provider_mod, model, opts, [
             {"Content-Type", "application/json"}
           ]) do
      body = encode_body(model, prepared_text, opts) |> Jason.encode!()
      {:ok, Finch.build(:post, url, headers, body)}
    end
  end

  def build_request(_provider_mod, _model, _text, _opts) do
    {:error, Error.Invalid.Parameter.exception(parameter: "speech generation expects text input")}
  end

  @spec encode_body(LLMDB.Model.t(), String.t(), keyword()) :: map()
  def encode_body(model, text, opts) do
    provider_options = Keyword.get(opts, :provider_options, [])

    %{
      "model" => model.id,
      "input" => text,
      "voice" => Keyword.get(opts, :voice, "alloy"),
      "response_format" => normalize_output_format(Keyword.get(opts, :output_format, :mp3))
    }
    |> maybe_put_float("speed", Keyword.get(opts, :speed))
    |> maybe_put_provider_options(provider_options)
  end

  @spec decode_response(Finch.Response.t(), LLMDB.Model.t(), term(), keyword()) ::
          {:ok, Speech.Result.t()} | {:error, term()}
  def decode_response(%Finch.Response{body: body, headers: headers}, _model, _text, opts)
      when is_binary(body) do
    output_format = Keyword.get(opts, :output_format, :mp3)
    media_type = media_type_from_headers(headers) || format_to_media_type(output_format)

    {:ok,
     Speech.Result.new!(%{
       audio: body,
       media_type: media_type,
       format: normalize_output_format(output_format)
     })}
  end

  defp maybe_put_float(body, _key, nil), do: body
  defp maybe_put_float(body, key, value) when is_number(value), do: Map.put(body, key, value)
  defp maybe_put_float(body, _key, _value), do: body

  defp maybe_put_provider_options(body, opts) when is_map(opts) do
    maybe_put_provider_options(body, Map.to_list(opts))
  end

  defp maybe_put_provider_options(body, opts) when is_list(opts) do
    Enum.reduce(opts, body, fn
      {_key, nil}, acc -> acc
      {:instructions, value}, acc -> Map.put(acc, "instructions", value)
      {key, value}, acc -> Map.put(acc, to_string(key), value)
    end)
  end

  defp maybe_put_provider_options(body, _opts), do: body

  defp normalize_output_format(value) when value in [:mp3, :opus, :aac, :flac, :wav, :pcm] do
    Atom.to_string(value)
  end

  defp normalize_output_format(value) when is_binary(value), do: value
  defp normalize_output_format(_value), do: "mp3"

  defp format_to_media_type(:mp3), do: "audio/mpeg"
  defp format_to_media_type("mp3"), do: "audio/mpeg"
  defp format_to_media_type(:opus), do: "audio/opus"
  defp format_to_media_type("opus"), do: "audio/opus"
  defp format_to_media_type(:aac), do: "audio/aac"
  defp format_to_media_type("aac"), do: "audio/aac"
  defp format_to_media_type(:flac), do: "audio/flac"
  defp format_to_media_type("flac"), do: "audio/flac"
  defp format_to_media_type(:wav), do: "audio/wav"
  defp format_to_media_type("wav"), do: "audio/wav"
  defp format_to_media_type(:pcm), do: "audio/pcm"
  defp format_to_media_type("pcm"), do: "audio/pcm"
  defp format_to_media_type(_format), do: "audio/mpeg"

  defp media_type_from_headers(headers) when is_list(headers) do
    headers
    |> Enum.find_value(fn {key, value} ->
      if String.downcase(to_string(key)) == "content-type" do
        value |> to_string() |> String.split(";", parts: 2) |> List.first()
      end
    end)
  end

  defp media_type_from_headers(_headers), do: nil
end
