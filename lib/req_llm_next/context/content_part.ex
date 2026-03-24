defmodule ReqLlmNext.Context.ContentPart do
  @moduledoc """
  ContentPart represents a single piece of content within a message.

  Supports multiple content types:
  - `:text` - Plain text content
  - `:image_url` - Image from URL
  - `:image` - Image from binary data
  - `:file` - File attachment
  - `:document` - Document content or document reference
  - `:search_result` - Search result content with provider metadata
  - `:thinking` - Chain-of-thought thinking content

  ## See also

  - `ReqLlmNext.Context.Message` - Multi-modal message composition using ContentPart collections
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              type: Zoi.enum([:text, :image_url, :image, :file, :document, :search_result, :thinking]),
              text: Zoi.string() |> Zoi.nullish(),
              url: Zoi.string() |> Zoi.nullish(),
              data: Zoi.any() |> Zoi.nullish(),
              media_type: Zoi.string() |> Zoi.nullish(),
              filename: Zoi.string() |> Zoi.nullish(),
              metadata: Zoi.map() |> Zoi.default(%{})
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @doc "Returns the Zoi schema for ContentPart"
  def schema, do: @schema

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs) do
    Zoi.parse(@schema, attrs)
  end

  @spec new!(map()) :: t()
  def new!(attrs) when is_map(attrs) do
    case new(attrs) do
      {:ok, part} -> part
      {:error, reason} -> raise ArgumentError, "Invalid content part: #{inspect(reason)}"
    end
  end

  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{type: type}) when is_atom(type), do: true
  def valid?(_), do: false

  @spec text(String.t()) :: t()
  def text(content), do: %__MODULE__{type: :text, text: content}

  @spec text(String.t(), map()) :: t()
  def text(content, metadata), do: %__MODULE__{type: :text, text: content, metadata: metadata}

  @spec thinking(String.t()) :: t()
  def thinking(content), do: %__MODULE__{type: :thinking, text: content}

  @spec thinking(String.t(), map()) :: t()
  def thinking(content, metadata),
    do: %__MODULE__{type: :thinking, text: content, metadata: metadata}

  @spec image_url(String.t()) :: t()
  def image_url(url), do: %__MODULE__{type: :image_url, url: url}

  @spec image(binary(), String.t()) :: t()
  def image(data, media_type \\ "image/png"),
    do: %__MODULE__{type: :image, data: data, media_type: media_type}

  @spec data_uri(t()) :: String.t() | nil
  def data_uri(%__MODULE__{type: :image, data: data, media_type: media_type})
      when is_binary(data) and is_binary(media_type) do
    "data:#{media_type};base64,#{Base.encode64(data)}"
  end

  def data_uri(%__MODULE__{type: :image_url, url: url}) when is_binary(url), do: url
  def data_uri(_), do: nil

  @spec parse_data_uri(String.t()) :: {:ok, %{media_type: String.t(), data: binary()}} | :error
  def parse_data_uri("data:" <> rest) do
    case String.split(rest, ";base64,", parts: 2) do
      [media_type, encoded] when media_type != "" ->
        case Base.decode64(encoded) do
          {:ok, data} -> {:ok, %{media_type: media_type, data: data}}
          :error -> :error
        end

      _ ->
        :error
    end
  end

  def parse_data_uri(_), do: :error

  @spec file(binary(), String.t(), String.t()) :: t()
  def file(data, filename, media_type \\ "application/octet-stream"),
    do: %__MODULE__{type: :file, data: data, filename: filename, media_type: media_type}

  @spec document_text(String.t(), map()) :: t()
  def document_text(text, metadata \\ %{}) when is_binary(text) and is_map(metadata) do
    %__MODULE__{type: :document, data: text, media_type: "text/plain", metadata: metadata}
  end

  @spec document_binary(binary(), String.t(), map()) :: t()
  def document_binary(data, media_type \\ "application/pdf", metadata \\ %{})
      when is_binary(data) and is_binary(media_type) and is_map(metadata) do
    %__MODULE__{type: :document, data: data, media_type: media_type, metadata: metadata}
  end

  @spec document_url(String.t(), String.t(), map()) :: t()
  def document_url(url, media_type \\ "application/pdf", metadata \\ %{})
      when is_binary(url) and is_binary(media_type) and is_map(metadata) do
    %__MODULE__{type: :document, url: url, media_type: media_type, metadata: metadata}
  end

  @spec document_file_id(String.t(), map()) :: t()
  def document_file_id(file_id, metadata \\ %{}) when is_binary(file_id) and is_map(metadata) do
    %__MODULE__{
      type: :document,
      data: file_id,
      metadata: Map.put(metadata, :source_type, :file_id)
    }
  end

  @spec search_result(String.t(), String.t(), String.t(), map()) :: t()
  def search_result(title, url, text, metadata \\ %{})
      when is_binary(title) and is_binary(url) and is_binary(text) and is_map(metadata) do
    %__MODULE__{
      type: :search_result,
      text: text,
      url: url,
      metadata: Map.put(metadata, :title, title)
    }
  end

  defimpl Inspect do
    import Kernel, except: [inspect: 2]

    def inspect(%{type: type} = part, opts) do
      content_desc =
        case type do
          :text -> inspect_text(part.text, opts)
          :thinking -> inspect_text(part.text, opts)
          :image_url -> "url: #{part.url}"
          :image -> "#{part.media_type} (#{byte_size(part.data)} bytes)"
          :file -> "#{part.media_type} (#{byte_size(part.data || <<>>)} bytes)"
          :document -> inspect_document(part, opts)
          :search_result -> inspect_search_result(part, opts)
        end

      Inspect.Algebra.concat([
        "#ContentPart<",
        Inspect.Algebra.to_doc(type, opts),
        " ",
        content_desc,
        ">"
      ])
    end

    defp inspect_text(text, _opts) when is_nil(text), do: "nil"

    defp inspect_text(text, _opts) do
      truncated = String.slice(text, 0, 30)
      if String.length(text) > 30, do: "\"#{truncated}...\"", else: "\"#{truncated}\""
    end

    defp inspect_document(%{data: data, media_type: media_type}, opts) when is_binary(data) do
      case data do
        "file_" <> _rest -> "file_id: #{inspect(data, opts)}"
        _ -> "#{media_type} (#{byte_size(data)} bytes)"
      end
    end

    defp inspect_document(%{url: url}, _opts) when is_binary(url), do: "url: #{url}"
    defp inspect_document(%{data: data}, opts), do: Kernel.inspect(data, opts)

    defp inspect_search_result(%{metadata: metadata, url: url, text: text}, _opts) do
      title = Map.get(metadata || %{}, :title) || Map.get(metadata || %{}, "title") || "result"
      preview = String.slice(text || "", 0, 20)
      "#{title} #{url} \"#{preview}\""
    end
  end

  defimpl Jason.Encoder do
    def encode(%{data: data} = part, opts) when is_binary(data) do
      encoded_part = %{part | data: Base.encode64(data)}
      Jason.Encode.map(Map.from_struct(encoded_part), opts)
    end

    def encode(part, opts) do
      Jason.Encode.map(Map.from_struct(part), opts)
    end
  end
end
