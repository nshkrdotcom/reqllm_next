defmodule ReqLlmNext.Wire.OpenAITranscriptions do
  @moduledoc """
  OpenAI Audio Transcriptions API wire.
  """

  alias ReqLlmNext.Transcription
  alias ReqLlmNext.Transcription.AudioInput

  @spec path() :: String.t()
  def path, do: "/v1/audio/transcriptions"

  @spec translation_path() :: String.t()
  def translation_path, do: "/v1/audio/translations"

  @spec build_request(module(), LLMDB.Model.t(), term(), keyword()) ::
          {:ok, Finch.Request.t()} | {:error, term()}
  def build_request(provider_mod, model, input, opts) do
    with {:ok, audio} <- resolved_audio(input, opts) do
      api_key = provider_mod.get_api_key(opts)
      base_url = Keyword.get(opts, :base_url, provider_mod.base_url())
      url = base_url <> request_path(opts)
      boundary = multipart_boundary()

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
    [
      multipart_part(boundary, "file", audio.data, audio.filename, audio.media_type),
      multipart_field(boundary, "model", model.id),
      multipart_field(boundary, "response_format", transcription_response_format(model, opts)),
      maybe_field(boundary, "language", Keyword.get(opts, :language)),
      maybe_field(boundary, "prompt", Keyword.get(opts, :prompt)),
      provider_option_fields(boundary, Keyword.get(opts, :provider_options, [])),
      "--#{boundary}--\r\n"
    ]
    |> List.flatten()
    |> IO.iodata_to_binary()
  end

  defp transcription_response_format(model, opts) do
    case Keyword.get(opts, :response_format) do
      nil -> default_response_format(model)
      value -> normalize_response_format(value)
    end
  end

  defp default_response_format(%LLMDB.Model{id: id}) do
    if String.contains?(id || "", "transcribe") do
      "json"
    else
      "verbose_json"
    end
  end

  defp provider_option_fields(boundary, opts) when is_map(opts),
    do: provider_option_fields(boundary, Map.to_list(opts))

  defp provider_option_fields(boundary, opts) when is_list(opts) do
    Enum.flat_map(opts, fn
      {_key, nil} ->
        []

      {:timestamp_granularities, values} when is_list(values) ->
        Enum.map(values, &multipart_field(boundary, "timestamp_granularities[]", to_string(&1)))

      {key, value} ->
        [multipart_field(boundary, to_string(key), to_string(value))]
    end)
  end

  defp provider_option_fields(_boundary, _opts), do: []

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
    "reqllmnext-" <> Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)
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

  defp normalize_response_format(value)
       when value in [:json, :text, :srt, :verbose_json, :vtt] do
    Atom.to_string(value)
  end

  defp normalize_response_format(value) when is_binary(value), do: value
  defp normalize_response_format(_value), do: "json"

  defp request_path(opts) do
    if Keyword.get(opts, :_translation?, false) or
         Keyword.get(opts, :translate, false) or
         Keyword.get(opts, :task) in [:translate, "translate"] do
      translation_path()
    else
      path()
    end
  end

  defp parse_result(body) do
    text = body["text"] || parse_multichannel_text(body["transcripts"]) || ""

    segments =
      parse_segments(body["segments"]) ++
        parse_word_segments(body["words"]) ++
        parse_multichannel_segments(body["transcripts"])

    language =
      normalize_language(
        body["language"] || body["language_code"] ||
          parse_multichannel_language(body["transcripts"])
      )

    duration = body["duration"] || infer_duration(segments)

    Transcription.Result.new!(%{
      text: text,
      segments: segments,
      language: language,
      duration_in_seconds: duration,
      provider_meta: provider_meta(body, segments)
    })
  end

  defp parse_segments(segments) when is_list(segments) do
    Enum.map(segments, fn
      %{"text" => text, "start" => start_second, "end" => end_second} ->
        maybe_put_speaker(%{text: text, start_second: start_second, end_second: end_second}, nil)

      %{"text" => text, "start_second" => start_second, "end_second" => end_second} ->
        maybe_put_speaker(%{text: text, start_second: start_second, end_second: end_second}, nil)

      segment when is_map(segment) ->
        maybe_put_speaker(
          %{
            text: Map.get(segment, "text", ""),
            start_second: Map.get(segment, "start", Map.get(segment, "start_second")),
            end_second: Map.get(segment, "end", Map.get(segment, "end_second"))
          },
          Map.get(segment, "speaker") || Map.get(segment, "speaker_label")
        )
    end)
  end

  defp parse_segments(_segments), do: []

  defp parse_word_segments(words) when is_list(words) do
    Enum.map(words, fn word ->
      maybe_put_speaker(
        %{
          text: Map.get(word, "text", ""),
          start_second: Map.get(word, "start", Map.get(word, "start_second")),
          end_second: Map.get(word, "end", Map.get(word, "end_second"))
        },
        Map.get(word, "speaker") || Map.get(word, "speaker_label")
      )
    end)
  end

  defp parse_word_segments(_words), do: []

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
      speaker = transcript["speaker"] || transcript["speaker_label"] || transcript["channel"]

      transcript
      |> Map.get("segments", [])
      |> parse_segments()
      |> Enum.map(&maybe_put_speaker(&1, speaker))
    end)
  end

  defp parse_multichannel_segments(_transcripts), do: []

  defp parse_multichannel_language(transcripts) when is_list(transcripts) do
    transcripts
    |> Enum.find_value(fn transcript ->
      Map.get(transcript, "language_code") || Map.get(transcript, "language")
    end)
  end

  defp parse_multichannel_language(_transcripts), do: nil

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
      values -> Enum.max(values)
    end
  end

  defp provider_meta(body, segments) do
    %{}
    |> maybe_put(:task, body["task"])
    |> maybe_put(:translation, body["translated_text"])
    |> maybe_put(:speaker_count, speaker_count(segments))
  end

  defp speaker_count(segments) when is_list(segments) do
    segments
    |> Enum.map(&Map.get(&1, :speaker))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> length()
    |> case do
      0 -> nil
      count -> count
    end
  end

  defp maybe_put_speaker(segment, nil), do: segment
  defp maybe_put_speaker(segment, speaker), do: Map.put(segment, :speaker, speaker)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
