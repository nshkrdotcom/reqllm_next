defmodule ReqLlmNext.Wire.OpenAIImages do
  @moduledoc """
  OpenAI Images API wire for non-streaming image generation.
  """

  alias ReqLlmNext.Context
  alias ReqLlmNext.Context.ContentPart
  alias ReqLlmNext.Provider
  alias ReqLlmNext.Response
  alias ReqLlmNext.SurfacePreparation.OpenAIImages, as: ImagePreparation

  @spec path() :: String.t()
  def path, do: "/v1/images/generations"

  @spec edit_path() :: String.t()
  def edit_path, do: "/v1/images/edits"

  @spec build_request(module(), LLMDB.Model.t(), String.t() | Context.t(), keyword()) ::
          {:ok, Finch.Request.t()} | {:error, term()}
  def build_request(provider_mod, model, prompt, opts) do
    with {:ok, text_prompt} <- prepared_prompt(prompt, opts) do
      edit? = image_edit?(opts)

      {headers, body, path, request_opts} =
        if edit? do
          boundary = multipart_boundary()

          {
            [{"Content-Type", "multipart/form-data; boundary=#{boundary}"}],
            encode_edit_body(model, text_prompt, opts, boundary),
            edit_path(),
            Keyword.put(opts, :path, edit_path())
          }
        else
          {
            headers(opts),
            encode_body(model, text_prompt, opts) |> Jason.encode!(),
            path(),
            Keyword.put(opts, :path, path())
          }
        end

      with {:ok, url} <- Provider.request_url(provider_mod, model, path, request_opts),
           {:ok, request_headers} <-
             Provider.request_headers(provider_mod, model, request_opts, headers) do
        {:ok, Finch.build(:post, url, request_headers, body)}
      end
    end
  end

  @spec headers(keyword()) :: [{String.t(), String.t()}]
  def headers(_opts), do: [{"Content-Type", "application/json"}]

  @spec encode_body(LLMDB.Model.t(), String.t(), keyword()) :: map()
  def encode_body(model, prompt, opts) do
    %{
      "model" => model.id,
      "prompt" => prompt,
      "n" => Keyword.get(opts, :n, 1)
    }
    |> maybe_put_size(Keyword.get(opts, :size))
    |> maybe_put_string("quality", Keyword.get(opts, :quality))
    |> maybe_put_string("style", Keyword.get(opts, :style))
    |> maybe_put_string("user", Keyword.get(opts, :user))
    |> maybe_put_output_format(Keyword.get(opts, :output_format))
    |> maybe_put_integer("seed", Keyword.get(opts, :seed))
    |> maybe_put_string("negative_prompt", Keyword.get(opts, :negative_prompt))
    |> maybe_put_response_format(model.id, Keyword.get(opts, :response_format))
  end

  @spec decode_response(Finch.Response.t(), LLMDB.Model.t(), term(), keyword()) ::
          {:ok, Response.t()} | {:error, term()}
  def decode_response(%Finch.Response{body: body}, model, prompt, opts) do
    with {:ok, decoded} <- Jason.decode(body),
         {:ok, context} <- normalize_context(prompt) do
      {:ok, decode_images_response(model, context, decoded, opts)}
    else
      {:error, %Jason.DecodeError{} = error} ->
        {:error,
         ReqLlmNext.Error.API.JsonParse.exception(
           message: "Failed to parse OpenAI image response: #{Exception.message(error)}",
           raw_json: body
         )}

      {:error, _} = error ->
        error
    end
  end

  defp normalize_context(%Context{} = context), do: {:ok, context}
  defp normalize_context(prompt) when is_binary(prompt), do: Context.normalize(prompt)
  defp normalize_context(prompt), do: Context.normalize(prompt)

  defp prepared_prompt(prompt, opts) do
    case Keyword.get(opts, :_prepared_prompt) do
      prompt when is_binary(prompt) and prompt != "" -> {:ok, prompt}
      _ -> ImagePreparation.extract_prompt(Keyword.get(opts, :_request_input, prompt))
    end
  end

  defp image_edit?(opts), do: Keyword.get(opts, :_image_edit?, false)

  defp encode_edit_body(model, prompt, opts, boundary) do
    images = Keyword.get(opts, :_prepared_images, [])
    mask = Keyword.get(opts, :_prepared_mask)

    [
      multipart_field(boundary, "model", model.id),
      multipart_field(boundary, "prompt", prompt),
      multipart_field(boundary, "n", Integer.to_string(Keyword.get(opts, :n, 1))),
      maybe_multipart_field(boundary, "size", normalize_size(Keyword.get(opts, :size))),
      maybe_multipart_field(boundary, "quality", normalize_value(Keyword.get(opts, :quality))),
      maybe_multipart_field(boundary, "style", normalize_value(Keyword.get(opts, :style))),
      maybe_multipart_field(
        boundary,
        "output_format",
        normalize_output_format_value(Keyword.get(opts, :output_format))
      ),
      maybe_multipart_field(boundary, "user", Keyword.get(opts, :user)),
      Enum.with_index(images)
      |> Enum.map(fn {image, index} ->
        multipart_file(
          boundary,
          if(index == 0, do: "image", else: "image[]"),
          Map.get(image, :filename, "image-#{index + 1}.png"),
          image.media_type,
          image.data
        )
      end),
      maybe_mask_part(boundary, mask),
      "--#{boundary}--\r\n"
    ]
    |> List.flatten()
    |> IO.iodata_to_binary()
  end

  defp decode_images_response(model, context, %{"data" => data} = body, opts)
       when is_list(data) do
    parts =
      data
      |> Enum.map(&decode_image_item(&1, Keyword.get(opts, :output_format, :png)))
      |> Enum.reject(&is_nil/1)

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
      provider_meta: Map.drop(body, ["data"])
    })
  end

  defp decode_images_response(model, context, body, _opts) do
    Response.new!(%{
      id: image_response_id(),
      model: model,
      context: context,
      message: nil,
      stream?: false,
      stream: nil,
      usage: nil,
      finish_reason: :error,
      provider_meta: %{"openai" => body},
      error:
        ReqLlmNext.Error.API.Response.exception(
          reason: "Invalid OpenAI image response format",
          response_body: body
        )
    })
  end

  defp decode_image_item(%{"b64_json" => encoded} = item, output_format)
       when is_binary(encoded) do
    revised_prompt = Map.get(item, "revised_prompt")
    metadata = if is_binary(revised_prompt), do: %{revised_prompt: revised_prompt}, else: %{}
    media_type = output_format_to_media_type(output_format)
    ContentPart.image(Base.decode64!(encoded), media_type) |> put_metadata(metadata)
  end

  defp decode_image_item(%{"url" => url} = item, _output_format) when is_binary(url) do
    revised_prompt = Map.get(item, "revised_prompt")
    metadata = if is_binary(revised_prompt), do: %{revised_prompt: revised_prompt}, else: %{}
    ContentPart.image_url(url) |> put_metadata(metadata)
  end

  defp decode_image_item(_item, _output_format), do: nil

  defp put_metadata(%ContentPart{} = part, metadata) when metadata == %{}, do: part
  defp put_metadata(%ContentPart{} = part, metadata), do: %{part | metadata: metadata}

  defp maybe_put_response_format(body, model_id, response_format) do
    if String.starts_with?(model_id || "", "dall-e-") do
      Map.put(body, "response_format", normalize_response_format(response_format))
    else
      body
    end
  end

  defp multipart_boundary do
    "reqllmnext-" <> Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)
  end

  defp multipart_file(boundary, name, filename, content_type, data) do
    [
      "--#{boundary}\r\n",
      "Content-Disposition: form-data; name=\"#{name}\"; filename=\"#{filename}\"\r\n",
      "Content-Type: #{content_type}\r\n\r\n",
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

  defp maybe_mask_part(_boundary, nil), do: []

  defp maybe_mask_part(boundary, %{data: data, media_type: media_type, filename: filename}) do
    multipart_file(boundary, "mask", filename, media_type, data)
  end

  defp maybe_multipart_field(_boundary, _name, nil), do: []
  defp maybe_multipart_field(boundary, name, value), do: multipart_field(boundary, name, value)

  defp normalize_size(nil), do: nil

  defp normalize_size({width, height}) when is_integer(width) and is_integer(height),
    do: "#{width}x#{height}"

  defp normalize_size(size) when is_binary(size), do: size
  defp normalize_size(_size), do: nil

  defp normalize_value(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_value(value) when is_binary(value), do: value
  defp normalize_value(_value), do: nil

  defp maybe_put_size(body, nil), do: body

  defp maybe_put_size(body, {width, height}) when is_integer(width) and is_integer(height) do
    Map.put(body, "size", "#{width}x#{height}")
  end

  defp maybe_put_size(body, size) when is_binary(size), do: Map.put(body, "size", size)
  defp maybe_put_size(body, _size), do: body

  defp maybe_put_string(body, _key, nil), do: body

  defp maybe_put_string(body, key, value) when is_atom(value),
    do: Map.put(body, key, Atom.to_string(value))

  defp maybe_put_string(body, key, value) when is_binary(value), do: Map.put(body, key, value)
  defp maybe_put_string(body, _key, _value), do: body

  defp maybe_put_integer(body, _key, nil), do: body
  defp maybe_put_integer(body, key, value) when is_integer(value), do: Map.put(body, key, value)
  defp maybe_put_integer(body, _key, _value), do: body

  defp maybe_put_output_format(body, nil), do: body

  defp maybe_put_output_format(body, value) when value in [:png, :jpeg, :webp],
    do: Map.put(body, "output_format", Atom.to_string(value))

  defp maybe_put_output_format(body, value) when is_binary(value),
    do: Map.put(body, "output_format", value)

  defp maybe_put_output_format(body, _value), do: body

  defp normalize_response_format(:url), do: "url"
  defp normalize_response_format(:binary), do: "b64_json"
  defp normalize_response_format("url"), do: "url"
  defp normalize_response_format("b64_json"), do: "b64_json"
  defp normalize_response_format(_value), do: "b64_json"

  defp normalize_output_format_value(nil), do: nil
  defp normalize_output_format_value(:png), do: "png"
  defp normalize_output_format_value(:jpeg), do: "jpeg"
  defp normalize_output_format_value(:webp), do: "webp"
  defp normalize_output_format_value(value) when is_binary(value), do: value
  defp normalize_output_format_value(_value), do: nil

  defp output_format_to_media_type(:jpeg), do: "image/jpeg"
  defp output_format_to_media_type("jpeg"), do: "image/jpeg"
  defp output_format_to_media_type(:webp), do: "image/webp"
  defp output_format_to_media_type("webp"), do: "image/webp"
  defp output_format_to_media_type(_format), do: "image/png"

  defp image_response_id do
    "img_" <> (:crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false))
  end
end
