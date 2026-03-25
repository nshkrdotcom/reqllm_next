defmodule ReqLlmNext.Wire.OpenAIImages do
  @moduledoc """
  OpenAI Images API wire for non-streaming image generation.
  """

  alias ReqLlmNext.Context
  alias ReqLlmNext.Context.ContentPart
  alias ReqLlmNext.Response
  alias ReqLlmNext.SurfacePreparation.OpenAIImages, as: ImagePreparation

  @spec path() :: String.t()
  def path, do: "/v1/images/generations"

  @spec build_request(module(), LLMDB.Model.t(), String.t() | Context.t(), keyword()) ::
          {:ok, Finch.Request.t()} | {:error, term()}
  def build_request(provider_mod, model, prompt, opts) do
    with {:ok, text_prompt} <- prepared_prompt(prompt, opts) do
      api_key = provider_mod.get_api_key(opts)
      base_url = Keyword.get(opts, :base_url, provider_mod.base_url())
      url = base_url <> path()
      headers = provider_mod.auth_headers(api_key) ++ headers(opts)
      body = encode_body(model, text_prompt, opts) |> Jason.encode!()
      {:ok, Finch.build(:post, url, headers, body)}
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

  defp output_format_to_media_type(:jpeg), do: "image/jpeg"
  defp output_format_to_media_type("jpeg"), do: "image/jpeg"
  defp output_format_to_media_type(:webp), do: "image/webp"
  defp output_format_to_media_type("webp"), do: "image/webp"
  defp output_format_to_media_type(_format), do: "image/png"

  defp image_response_id do
    "img_" <> (:crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false))
  end
end
