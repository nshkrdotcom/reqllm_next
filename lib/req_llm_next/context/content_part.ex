defmodule ReqLlmNext.Context.ContentPart do
  @moduledoc """
  ContentPart represents a single piece of content within a message.

  Supports multiple content types:
  - `:text` - Plain text content
  - `:image_url` - Image from URL
  - `:image` - Image from binary data
  - `:file` - File attachment
  - `:thinking` - Chain-of-thought thinking content

  ## See also

  - `ReqLlmNext.Context.Message` - Multi-modal message composition using ContentPart collections
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              type: Zoi.enum([:text, :image_url, :image, :file, :thinking]),
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

  defimpl Inspect do
    def inspect(%{type: type} = part, opts) do
      content_desc =
        case type do
          :text -> inspect_text(part.text, opts)
          :thinking -> inspect_text(part.text, opts)
          :image_url -> "url: #{part.url}"
          :image -> "#{part.media_type} (#{byte_size(part.data)} bytes)"
          :file -> "#{part.media_type} (#{byte_size(part.data || <<>>)} bytes)"
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
