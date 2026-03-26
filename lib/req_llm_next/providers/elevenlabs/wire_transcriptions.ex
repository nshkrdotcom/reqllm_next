defmodule ReqLlmNext.Wire.ElevenLabsTranscriptions do
  @moduledoc """
  ElevenLabs speech-to-text wire.
  """

  alias ReqLlmNext.Transcription
  alias ReqLlmNext.Transcription.AudioInput

  @spec path() :: String.t()
  def path, do: "/v1/speech-to-text"

  @spec build_request(module(), LLMDB.Model.t(), term(), keyword()) ::
          {:ok, Finch.Request.t()} | {:error, term()}
  def build_request(provider_mod, model, input, opts) do
    with {:ok, audio} <- resolved_audio(input, opts) do
      api_key = provider_mod.get_api_key(opts)
      base_url = Keyword.get(opts, :base_url, provider_mod.base_url())
      boundary = multipart_boundary()
      query = query_string(Keyword.get(opts, :provider_options, []))
      url = base_url <> path() <> query

      headers =
        provider_mod.auth_headers(api_key) ++
          [{"Content-Type", "multipart/form-data; boundary=#{boundary}"}]

      body = multipart_body(model, audio, opts, boundary)
      {:ok, Finch.build(:post, url, headers, body)}
    end
  end

  @spec decode_response(Finch.Response.t(), LLMDB.Model.t(), term(), keyword()) ::
          {:ok, Transcription.Result.t()} | {:error, term()}
  def decode_response(%Finch.Response{body: body}, _model, _input, _opts) do
    case Jason.decode(body) do
      {:ok, decoded} when is_map(decoded) ->
        {:ok, parse_result(decoded)}

      {:ok, decoded} when is_binary(decoded) ->
        {:ok, Transcription.Result.new!(%{text: decoded})}

      {:ok, decoded} ->
        {:ok, Transcription.Result.new!(%{text: to_string(decoded)})}

      {:error, _decode_error} ->
        {:ok, Transcription.Result.new!(%{text: body})}
    end
  end

  defp multipart_body(model, audio, opts, boundary) do
    provider_options = normalize_provider_options(Keyword.get(opts, :provider_options, []))

    [
      multipart_part(boundary, "file", audio.data, audio.filename, audio.media_type),
      multipart_field(boundary, "model_id", model.id),
      maybe_field(boundary, "language_code", Keyword.get(opts, :language)),
      provider_option_fields(boundary, provider_options),
      "--#{boundary}--\r\n"
    ]
    |> List.flatten()
    |> IO.iodata_to_binary()
  end

  defp query_string(opts) do
    provider_options = normalize_provider_options(opts)

    case Keyword.get(provider_options, :enable_logging) do
      nil -> ""
      value -> "?" <> URI.encode_query(%{"enable_logging" => value})
    end
  end

  defp provider_option_fields(boundary, opts) do
    Enum.flat_map(opts, fn
      {:enable_logging, _value} ->
        []

      {_key, nil} ->
        []

      {:keyterms, values} when is_list(values) ->
        Enum.map(values, &multipart_field(boundary, "keyterms", to_string(&1)))

      {key, value} when is_map(value) ->
        [multipart_field(boundary, to_string(key), Jason.encode!(value))]

      {key, value} when is_list(value) ->
        Enum.map(value, &multipart_field(boundary, to_string(key), to_string(&1)))

      {key, value} ->
        [multipart_field(boundary, to_string(key), to_string(value))]
    end)
  end

  defp maybe_field(_boundary, _name, nil), do: []
  defp maybe_field(boundary, name, value), do: [multipart_field(boundary, name, to_string(value))]

  defp multipart_part(boundary, name, data, filename, media_type) do
    [
      "--#{boundary}\r\n",
      "Content-Disposition: form-data; name=\"#{name}\"; filename=\"#{filename}\"\r\n",
      "Content-Type: #{media_type}\r\n\r\n",
      data,
      "\r\n"
    ]
  end

  defp multipart_field(boundary, name, value) do
    [
      "--#{boundary}\r\n",
      "Content-Disposition: form-data; name=\"#{name}\"\r\n\r\n",
      value,
      "\r\n"
    ]
  end

  defp multipart_boundary do
    "reqllmnext-elevenlabs-" <> Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)
  end

  defp resolved_audio(input, opts) do
    case Keyword.get(opts, :_resolved_audio_input) do
      %{data: data, media_type: media_type, filename: filename} = audio
      when is_binary(data) and is_binary(media_type) and is_binary(filename) ->
        {:ok, audio}

      _ ->
        AudioInput.resolve(Keyword.get(opts, :_request_input, input))
    end
  end

  defp normalize_provider_options(opts) when is_map(opts), do: Map.to_list(opts)
  defp normalize_provider_options(opts) when is_list(opts), do: opts
  defp normalize_provider_options(_opts), do: []

  defp parse_result(body) do
    text = body["text"] || parse_multichannel_text(body["transcripts"]) || ""
    segments = parse_segments(body["words"]) ++ parse_multichannel_segments(body["transcripts"])
    language = body["language_code"] || body["language"]
    duration = body["duration"] || infer_duration(segments)

    Transcription.Result.new!(%{
      text: text,
      segments: segments,
      language: normalize_language(language),
      duration_in_seconds: duration,
      provider_meta: provider_meta(body)
    })
  end

  defp parse_segments(words) when is_list(words) do
    Enum.map(words, fn word ->
      maybe_put_speaker(
        %{
          text: Map.get(word, "text", ""),
          start_second: Map.get(word, "start", Map.get(word, "start_second")),
          end_second: Map.get(word, "end", Map.get(word, "end_second")),
          type: Map.get(word, "type"),
          confidence: Map.get(word, "confidence", Map.get(word, "logprob"))
        },
        Map.get(word, "speaker") || Map.get(word, "speaker_label") || Map.get(word, "speaker_id")
      )
    end)
  end

  defp parse_segments(_words), do: []

  defp parse_multichannel_text(transcripts) when is_list(transcripts) do
    transcripts
    |> Enum.map(&Map.get(&1, "text", ""))
    |> Enum.reject(&(&1 == ""))
    |> case do
      [] -> nil
      texts -> Enum.join(texts, "\n")
    end
  end

  defp parse_multichannel_text(_transcripts), do: nil

  defp parse_multichannel_segments(transcripts) when is_list(transcripts) do
    Enum.flat_map(transcripts, fn transcript ->
      speaker = transcript["speaker"] || transcript["speaker_label"] || transcript["speaker_id"]
      channel = transcript["channel"] || transcript["channel_id"]

      transcript
      |> Map.get("words", [])
      |> parse_segments()
      |> Enum.map(fn segment ->
        segment
        |> maybe_put_speaker(speaker)
        |> maybe_put(:channel, channel)
      end)
    end)
  end

  defp parse_multichannel_segments(_transcripts), do: []

  defp normalize_language(nil), do: nil
  defp normalize_language(language) when is_binary(language), do: language
  defp normalize_language(language), do: to_string(language)

  defp infer_duration([]), do: nil

  defp infer_duration(segments) do
    segments
    |> Enum.map(&Map.get(&1, :end_second))
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      durations -> Enum.max(durations)
    end
  end

  defp maybe_put_speaker(segment, nil), do: segment
  defp maybe_put_speaker(segment, speaker), do: Map.put(segment, :speaker, speaker)

  defp maybe_put(segment, _key, nil), do: segment
  defp maybe_put(segment, key, value), do: Map.put(segment, key, value)

  defp provider_meta(body) do
    body
    |> Map.drop(["text", "language", "language_code", "words", "transcripts", "duration"])
    |> Enum.into(%{}, fn {key, value} -> {String.to_atom(key), value} end)
  end
end
