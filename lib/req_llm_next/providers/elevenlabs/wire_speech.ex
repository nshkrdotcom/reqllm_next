defmodule ReqLlmNext.Wire.ElevenLabsSpeech do
  @moduledoc """
  ElevenLabs text-to-speech wire.
  """

  alias ReqLlmNext.Error
  alias ReqLlmNext.Provider
  alias ReqLlmNext.Speech

  @default_voice "21m00Tcm4TlvDq8ikWAM"

  @format_mapping %{
    mp3: "mp3_44100_128",
    pcm: "pcm_44100",
    opus: "opus_48000_64",
    wav: "wav_44100"
  }

  @reverse_format_mapping Map.new(@format_mapping, fn {key, value} ->
                            {value, Atom.to_string(key)}
                          end)

  @spec path(String.t()) :: String.t()
  def path(voice_id), do: "/v1/text-to-speech/#{voice_id}"

  @spec build_request(module(), LLMDB.Model.t(), String.t(), keyword()) ::
          {:ok, Finch.Request.t()} | {:error, term()}
  def build_request(provider_mod, model, text, opts) when is_binary(text) do
    prepared_text = Keyword.get(opts, :_prepared_text, text)
    voice_id = Keyword.get(opts, :voice, @default_voice)
    request_path = path(voice_id)
    request_opts = Keyword.put(opts, :path, request_path)

    with {:ok, url} <- Provider.request_url(provider_mod, model, request_path, request_opts),
         {:ok, headers} <-
           Provider.request_headers(provider_mod, model, request_opts, [
             {"Content-Type", "application/json"}
           ]) do
      body = encode_body(model, prepared_text, opts) |> Jason.encode!()
      {:ok, Finch.build(:post, append_output_query(url, opts), headers, body)}
    end
  end

  def build_request(_provider_mod, _model, _text, _opts) do
    {:error, Error.Invalid.Parameter.exception(parameter: "speech generation expects text input")}
  end

  @spec encode_body(LLMDB.Model.t(), String.t(), keyword()) :: map()
  def encode_body(model, text, opts) do
    provider_options = normalize_provider_options(Keyword.get(opts, :provider_options, []))

    %{
      "text" => text,
      "model_id" => model.id
    }
    |> maybe_put("language_code", Keyword.get(opts, :language))
    |> maybe_put("voice_settings", voice_settings(provider_options))
    |> maybe_put_provider_options(provider_options)
  end

  @spec decode_response(Finch.Response.t(), LLMDB.Model.t(), term(), keyword()) ::
          {:ok, Speech.Result.t()} | {:error, term()}
  def decode_response(%Finch.Response{body: body, headers: headers}, _model, _text, opts)
      when is_binary(body) do
    requested_format = requested_output_format(opts)

    {:ok,
     Speech.Result.new!(%{
       audio: body,
       media_type: media_type_from_headers(headers) || media_type_for(requested_format),
       format: result_format(requested_format),
       provider_meta: response_metadata(headers)
     })}
  end

  defp output_query(opts) do
    %{"output_format" => mapped_output_format(Keyword.get(opts, :output_format, :mp3))}
  end

  defp append_output_query(url, opts) do
    uri = URI.parse(url)
    query = Map.merge(URI.decode_query(uri.query || ""), output_query(opts))
    %{uri | query: URI.encode_query(query)} |> URI.to_string()
  end

  defp requested_output_format(opts) do
    Keyword.get(opts, :output_format, :mp3)
  end

  defp mapped_output_format(format) when is_atom(format) do
    Map.get(@format_mapping, format, "mp3_44100_128")
  end

  defp mapped_output_format(format) when is_binary(format), do: format
  defp mapped_output_format(_format), do: "mp3_44100_128"

  defp result_format(format) when is_atom(format), do: Atom.to_string(format)

  defp result_format(format) when is_binary(format),
    do: Map.get(@reverse_format_mapping, format, format)

  defp result_format(_format), do: "mp3"

  defp media_type_for(:mp3), do: "audio/mpeg"
  defp media_type_for("mp3"), do: "audio/mpeg"
  defp media_type_for(:pcm), do: "audio/pcm"
  defp media_type_for("pcm"), do: "audio/pcm"
  defp media_type_for(:opus), do: "audio/opus"
  defp media_type_for("opus"), do: "audio/opus"
  defp media_type_for(:wav), do: "audio/wav"
  defp media_type_for("wav"), do: "audio/wav"
  defp media_type_for("mp3_44100_128"), do: "audio/mpeg"
  defp media_type_for("pcm_44100"), do: "audio/pcm"
  defp media_type_for("opus_48000_64"), do: "audio/opus"
  defp media_type_for("wav_44100"), do: "audio/wav"
  defp media_type_for(_format), do: "audio/mpeg"

  defp normalize_provider_options(opts) when is_map(opts), do: Map.to_list(opts)
  defp normalize_provider_options(opts) when is_list(opts), do: opts
  defp normalize_provider_options(_opts), do: []

  defp voice_settings(opts) do
    %{}
    |> maybe_put("stability", opts[:stability])
    |> maybe_put("similarity_boost", opts[:similarity_boost])
    |> maybe_put("style", opts[:style])
    |> maybe_put("speed", opts[:speed])
    |> maybe_put("use_speaker_boost", opts[:use_speaker_boost])
    |> case do
      settings when map_size(settings) == 0 -> nil
      settings -> settings
    end
  end

  defp maybe_put_provider_options(body, opts) do
    ignored_keys = [:stability, :similarity_boost, :style, :speed, :use_speaker_boost]

    Enum.reduce(opts, body, fn
      {key, value}, acc ->
        cond do
          key in ignored_keys ->
            acc

          is_nil(value) ->
            acc

          true ->
            Map.put(acc, to_string(key), value)
        end
    end)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp media_type_from_headers(headers) when is_list(headers) do
    headers
    |> Enum.find_value(fn {key, value} ->
      if String.downcase(to_string(key)) == "content-type" do
        value |> to_string() |> String.split(";", parts: 2) |> List.first()
      end
    end)
  end

  defp media_type_from_headers(_headers), do: nil

  defp response_metadata(headers) when is_list(headers) do
    headers
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      case String.downcase(to_string(key)) do
        "request-id" -> Map.put(acc, :request_id, value)
        "x-request-id" -> Map.put(acc, :request_id, value)
        "character-cost" -> Map.put(acc, :character_cost, value)
        "x-character-cost" -> Map.put(acc, :character_cost, value)
        _ -> acc
      end
    end)
  end

  defp response_metadata(_headers), do: %{}
end
