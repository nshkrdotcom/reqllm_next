defmodule ReqLlmNext.SurfacePreparation.OpenAIImages do
  @moduledoc """
  OpenAI image-generation request preparation.
  """

  alias ReqLlmNext.Context
  alias ReqLlmNext.Context.ContentPart
  alias ReqLlmNext.Error
  alias ReqLlmNext.ExecutionSurface

  @spec prepare(ExecutionSurface.t(), term(), keyword()) :: {:ok, keyword()} | {:error, term()}
  def prepare(%ExecutionSurface{}, prompt, opts) do
    with {:ok, prepared_prompt} <- extract_prompt(prompt),
         {:ok, prepared_images} <- extract_images(prompt, opts),
         {:ok, prepared_mask} <- extract_mask(opts) do
      {:ok,
       opts
       |> Keyword.put(:_prepared_prompt, prepared_prompt)
       |> Keyword.put(:_prepared_images, prepared_images)
       |> Keyword.put(:_prepared_mask, prepared_mask)
       |> Keyword.put(:_image_edit?, prepared_images != [])}
    end
  end

  @spec validate(ExecutionSurface.t(), keyword()) :: :ok | {:error, term()}
  def validate(%ExecutionSurface{}, opts) do
    with :ok <- validate_prompt(opts),
         :ok <- validate_edit_inputs(opts),
         :ok <- validate_no_tools(opts),
         :ok <- validate_no_stream(opts) do
      ReqLlmNext.SurfacePreparation.validate_canonical_inputs(opts)
    end
  end

  defp validate_prompt(opts) do
    case Keyword.get(opts, :_prepared_prompt) do
      prompt when is_binary(prompt) and prompt != "" ->
        :ok

      _ ->
        case extract_prompt(Keyword.get(opts, :_request_input)) do
          {:ok, _prompt} ->
            :ok

          {:error, _} = error ->
            error
        end
    end
  end

  defp validate_edit_inputs(opts) do
    case Keyword.get(opts, :_prepared_images, []) do
      [] ->
        :ok

      images when is_list(images) ->
        case Enum.find(images, &invalid_edit_image?/1) do
          nil ->
            :ok

          _invalid ->
            {:error,
             Error.Invalid.Parameter.exception(
               parameter:
                 "image edits require binary or data-uri image inputs on the current OpenAI lane"
             )}
        end
    end
  end

  defp validate_no_tools(opts) do
    if Keyword.get(opts, :tools, []) == [] do
      :ok
    else
      {:error,
       Error.Invalid.Parameter.exception(parameter: "image generation does not support tools")}
    end
  end

  defp validate_no_stream(opts) do
    if Keyword.get(opts, :_stream?, false) do
      {:error,
       Error.Invalid.Parameter.exception(parameter: "image generation does not support streaming")}
    else
      :ok
    end
  end

  @spec extract_prompt(String.t() | Context.t() | term()) :: {:ok, String.t()} | {:error, term()}
  def extract_prompt(prompt) when is_binary(prompt) do
    normalized = String.trim(prompt)

    if normalized == "" do
      {:error,
       Error.Invalid.Parameter.exception(
         parameter: "image generation requires a non-empty user text prompt"
       )}
    else
      {:ok, normalized}
    end
  end

  def extract_prompt(%Context{messages: messages}) do
    prompt =
      messages
      |> Enum.reverse()
      |> Enum.find(&(&1.role == :user))
      |> case do
        nil ->
          ""

        %{content: content} when is_list(content) ->
          content
          |> Enum.filter(&(&1.type == :text))
          |> Enum.map(& &1.text)
          |> Enum.reject(&(&1 in [nil, ""]))
          |> Enum.join("\n")

        _ ->
          ""
      end
      |> String.trim()

    extract_prompt(prompt)
  end

  def extract_prompt(_prompt) do
    {:error,
     Error.Invalid.Parameter.exception(
       parameter: "image generation expects a string or ReqLlmNext.Context input"
     )}
  end

  @spec extract_images(term(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def extract_images(prompt, opts) do
    images =
      prompt
      |> prompt_images()
      |> Kernel.++(explicit_images(opts))

    {:ok, Enum.map(images, &normalize_edit_image/1)}
  end

  @spec extract_mask(keyword()) :: {:ok, map() | nil} | {:error, term()}
  def extract_mask(opts) do
    case Keyword.get(opts, :mask) do
      nil -> {:ok, nil}
      mask -> {:ok, normalize_edit_image(mask)}
    end
  end

  defp prompt_images(%Context{messages: messages}) do
    messages
    |> Enum.flat_map(fn message -> message.content || [] end)
    |> Enum.filter(&(&1.type in [:image, :image_url]))
  end

  defp prompt_images(_), do: []

  defp explicit_images(opts) do
    case Keyword.get(opts, :images) do
      images when is_list(images) -> images
      nil -> []
      image -> [image]
    end
  end

  defp normalize_edit_image(%ContentPart{type: :image, data: data, media_type: media_type}) do
    %{data: data, media_type: media_type || "image/png", filename: "image.png"}
  end

  defp normalize_edit_image(%ContentPart{type: :image_url, url: url}) when is_binary(url) do
    case ContentPart.parse_data_uri(url) do
      {:ok, %{data: data, media_type: media_type}} ->
        %{data: data, media_type: media_type, filename: "image.png"}

      :error ->
        %{url: url}
    end
  end

  defp normalize_edit_image({:binary, data, media_type})
       when is_binary(data) and is_binary(media_type) do
    %{data: data, media_type: media_type, filename: "image.png"}
  end

  defp normalize_edit_image(%{data: data, media_type: media_type} = image)
       when is_binary(data) and is_binary(media_type) do
    Map.put_new(image, :filename, "image.png")
  end

  defp normalize_edit_image(other), do: %{invalid: other}

  defp invalid_edit_image?(%{data: data, media_type: media_type})
       when is_binary(data) and is_binary(media_type),
       do: false

  defp invalid_edit_image?(_), do: true
end
