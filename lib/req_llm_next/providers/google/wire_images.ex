defmodule ReqLlmNext.Wire.GoogleImages do
  @moduledoc """
  Google image-generation wire covering Gemini image models and Imagen models.
  """

  alias ReqLlmNext.Context
  alias ReqLlmNext.Context.ContentPart
  alias ReqLlmNext.Provider
  alias ReqLlmNext.Response
  alias ReqLlmNext.Wire.GoogleGenerateContent

  @provider_option_keys [:google_api_version, :response_modalities, :google_candidate_count]

  @spec build_request(module(), LLMDB.Model.t(), String.t() | Context.t(), keyword()) ::
          {:ok, Finch.Request.t()} | {:error, term()}
  def build_request(provider_mod, model, prompt, opts) do
    request_path = request_path(model)

    request_opts =
      if Keyword.get(opts, :_use_runtime_metadata, false) do
        Keyword.put(opts, :path, request_path)
      else
        Keyword.put(
          opts,
          :base_url,
          effective_base_url(provider_mod.base_url(), provider_options(opts))
        )
        |> Keyword.put(:path, request_path)
      end

    with {:ok, url} <- Provider.request_url(provider_mod, model, request_path, request_opts),
         {:ok, headers} <-
           Provider.request_headers(
             provider_mod,
             model,
             request_opts,
             [{"Content-Type", "application/json"}]
           ) do
      body = encode_body(model, prompt, opts) |> Jason.encode!()
      {:ok, Finch.build(:post, url, headers, body)}
    end
  end

  @spec encode_body(LLMDB.Model.t(), String.t() | Context.t(), keyword()) :: map()
  def encode_body(%LLMDB.Model{id: id} = model, prompt, opts) when is_binary(id) do
    if imagen_model_id?(id) do
      encode_imagen_body(prompt, opts)
    else
      encode_gemini_body(model, prompt, opts)
    end
  end

  @spec decode_response(Finch.Response.t(), LLMDB.Model.t(), term(), keyword()) ::
          {:ok, Response.t()} | {:error, term()}
  def decode_response(%Finch.Response{body: body}, model, prompt, _opts) do
    with {:ok, decoded} <- Jason.decode(body),
         {:ok, context} <- normalize_context(prompt) do
      {:ok, decode_image_response(model, context, decoded)}
    else
      {:error, %Jason.DecodeError{} = error} ->
        {:error,
         ReqLlmNext.Error.API.JsonParse.exception(
           message: "Failed to parse Google image response: #{Exception.message(error)}",
           raw_json: body
         )}

      {:error, _} = error ->
        error
    end
  end

  defp encode_gemini_body(model, prompt, opts) do
    provider_options =
      opts
      |> provider_options()
      |> maybe_put_candidate_count(Keyword.get(opts, :n))
      |> maybe_put_response_modalities(Keyword.get(opts, :response_modalities, ["IMAGE"]))

    base_body =
      GoogleGenerateContent.encode_body(
        model,
        prompt,
        Keyword.put(opts, :provider_options, provider_options)
      )

    generation_config =
      base_body
      |> Map.get(:generationConfig, %{})
      |> maybe_put_google_response_modalities(provider_options[:response_modalities])
      |> maybe_put_google_aspect_ratio(Keyword.get(opts, :aspect_ratio))

    Map.put(base_body, :generationConfig, generation_config)
  end

  defp encode_imagen_body(prompt, opts) do
    image_prompt = imagen_prompt(prompt)

    parameters =
      %{}
      |> maybe_put(:sampleCount, Keyword.get(opts, :n))
      |> maybe_put(:aspectRatio, Keyword.get(opts, :aspect_ratio))
      |> maybe_put(:sampleImageSize, imagen_sample_image_size(Keyword.get(opts, :size)))
      |> maybe_put(:outputOptions, imagen_output_options(Keyword.get(opts, :output_format)))

    %{}
    |> Map.put(:instances, [%{prompt: image_prompt}])
    |> maybe_put(:parameters, if(parameters == %{}, do: nil, else: parameters))
  end

  defp decode_image_response(model, context, %{"predictions" => _predictions} = body) do
    parts =
      body
      |> Map.get("predictions", [])
      |> Enum.map(&decode_imagen_prediction/1)
      |> Enum.reject(&is_nil/1)

    response_for_parts(model, context, parts, Map.delete(body, "predictions"))
  end

  defp decode_image_response(model, context, %{"candidates" => _candidates} = body) do
    parts =
      body
      |> Map.get("candidates", [])
      |> Enum.flat_map(fn
        %{"content" => %{"parts" => parts}} when is_list(parts) -> parts
        _ -> []
      end)
      |> Enum.map(&decode_image_part/1)
      |> Enum.reject(&is_nil/1)

    response_for_parts(model, context, parts, Map.delete(body, "candidates"))
  end

  defp decode_image_response(model, context, body) do
    Response.new!(%{
      id: image_response_id(),
      model: model,
      context: context,
      message: nil,
      stream?: false,
      stream: nil,
      usage: nil,
      finish_reason: :error,
      provider_meta: %{"google" => body},
      error:
        ReqLlmNext.Error.API.Response.exception(
          reason: "Invalid Google image response format",
          response_body: body
        )
    })
  end

  defp response_for_parts(model, context, parts, provider_meta) do
    message = %Context.Message{role: :assistant, content: parts}
    updated_context = Context.append(context, message)

    Response.new!(%{
      id: image_response_id(),
      model: model,
      context: updated_context,
      message: message,
      stream?: false,
      stream: nil,
      usage: nil,
      finish_reason: :stop,
      provider_meta: %{"google" => provider_meta}
    })
  end

  defp decode_image_part(%{"text" => text}) when is_binary(text) and text != "" do
    ContentPart.text(text)
  end

  defp decode_image_part(%{"inlineData" => inline}) when is_map(inline),
    do: decode_inline_data(inline)

  defp decode_image_part(%{"inline_data" => inline}) when is_map(inline),
    do: decode_inline_data(inline)

  defp decode_image_part(_part), do: nil

  defp decode_inline_data(%{"data" => b64, "mimeType" => mime_type})
       when is_binary(b64) and is_binary(mime_type) do
    ContentPart.image(Base.decode64!(b64), mime_type)
  end

  defp decode_inline_data(%{"data" => b64, "mime_type" => mime_type})
       when is_binary(b64) and is_binary(mime_type) do
    ContentPart.image(Base.decode64!(b64), mime_type)
  end

  defp decode_inline_data(_inline), do: nil

  defp decode_imagen_prediction(%{"bytesBase64Encoded" => b64, "mimeType" => mime_type})
       when is_binary(b64) and is_binary(mime_type) do
    ContentPart.image(Base.decode64!(b64), mime_type)
  end

  defp decode_imagen_prediction(%{"gcsUri" => uri, "mimeType" => mime_type})
       when is_binary(uri) and is_binary(mime_type) do
    ContentPart.image_url(uri)
    |> Map.put(:metadata, %{mime_type: mime_type})
  end

  defp decode_imagen_prediction(_prediction), do: nil

  defp normalize_context(%Context{} = context), do: {:ok, context}
  defp normalize_context(prompt) when is_binary(prompt), do: Context.normalize(prompt)
  defp normalize_context(prompt), do: Context.normalize(prompt)

  defp imagen_prompt(%Context{messages: messages}) do
    messages
    |> Enum.map(&imagen_message_prompt/1)
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n\n")
    |> String.trim()
  end

  defp imagen_prompt(prompt) when is_binary(prompt), do: String.trim(prompt)
  defp imagen_prompt(_prompt), do: ""

  defp imagen_message_prompt(%Context.Message{role: role, content: content}) do
    prompt =
      content
      |> List.wrap()
      |> Enum.map(&imagen_content_prompt/1)
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.join("\n")
      |> String.trim()

    case {role, prompt} do
      {_, ""} -> nil
      {:user, value} -> value
      {message_role, value} -> "#{message_role}: #{value}"
    end
  end

  defp imagen_message_prompt(_message), do: nil

  defp imagen_content_prompt(%ContentPart{type: :text, text: text}) when is_binary(text), do: text
  defp imagen_content_prompt(%{type: :text, text: text}) when is_binary(text), do: text
  defp imagen_content_prompt(text) when is_binary(text), do: text
  defp imagen_content_prompt(_content), do: nil

  defp imagen_output_options(nil), do: nil

  defp imagen_output_options(output_format),
    do: %{mimeType: google_image_mime_type(output_format)}

  defp imagen_sample_image_size({width, height}) when is_integer(width) and is_integer(height),
    do: imagen_sample_image_size("#{width}x#{height}")

  defp imagen_sample_image_size(size) when is_binary(size) do
    case String.downcase(size) do
      "1024x1024" -> "1K"
      "2048x2048" -> "2K"
      _ -> nil
    end
  end

  defp imagen_sample_image_size(_size), do: nil

  defp google_image_mime_type(:png), do: "image/png"
  defp google_image_mime_type(:jpeg), do: "image/jpeg"
  defp google_image_mime_type(:webp), do: "image/webp"
  defp google_image_mime_type(format) when is_binary(format), do: format
  defp google_image_mime_type(_format), do: "image/png"

  defp request_path(%LLMDB.Model{id: id}) when is_binary(id) do
    if imagen_model_id?(id), do: "/models/#{id}:predict", else: "/models/#{id}:generateContent"
  end

  defp provider_options(opts) do
    opts
    |> Keyword.get(:provider_options, [])
    |> normalize_provider_options()
    |> Keyword.merge(Keyword.take(opts, @provider_option_keys))
  end

  defp normalize_provider_options(opts) when is_map(opts), do: Map.to_list(opts)
  defp normalize_provider_options(opts) when is_list(opts), do: opts
  defp normalize_provider_options(_opts), do: []

  defp effective_base_url(base_url, provider_options) do
    case provider_options[:google_api_version] do
      "v1" -> base_url <> "/v1"
      _ -> base_url <> "/v1beta"
    end
  end

  defp maybe_put_candidate_count(provider_options, nil), do: provider_options

  defp maybe_put_candidate_count(provider_options, count) do
    Keyword.put_new(provider_options, :google_candidate_count, count)
  end

  defp maybe_put_response_modalities(provider_options, nil), do: provider_options

  defp maybe_put_response_modalities(provider_options, modalities),
    do: Keyword.put(provider_options, :response_modalities, modalities)

  defp maybe_put_google_response_modalities(config, nil), do: config

  defp maybe_put_google_response_modalities(config, modalities) when is_list(modalities),
    do: Map.put(config, :responseModalities, modalities)

  defp maybe_put_google_response_modalities(config, _modalities), do: config

  defp maybe_put_google_aspect_ratio(config, nil), do: config

  defp maybe_put_google_aspect_ratio(config, ratio) when is_binary(ratio) do
    Map.put(
      config,
      :imageConfig,
      Map.put(Map.get(config, :imageConfig, %{}), :aspectRatio, ratio)
    )
  end

  defp maybe_put_google_aspect_ratio(config, _ratio), do: config

  defp imagen_model_id?(id) when is_binary(id), do: String.contains?(id, "imagen")

  defp image_response_id do
    "img_" <> (:crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
