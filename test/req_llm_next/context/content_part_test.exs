defmodule ReqLlmNext.Context.ContentPartTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Context.ContentPart

  describe "text/1" do
    test "creates text content part" do
      part = ContentPart.text("Hello, world!")

      assert %ContentPart{type: :text, text: "Hello, world!"} = part
    end

    test "creates text with empty string" do
      part = ContentPart.text("")

      assert part.type == :text
      assert part.text == ""
    end
  end

  describe "text/2" do
    test "creates text content part with metadata" do
      part = ContentPart.text("Hello", %{source: "test"})

      assert part.type == :text
      assert part.text == "Hello"
      assert part.metadata == %{source: "test"}
    end

    test "creates text with empty metadata" do
      part = ContentPart.text("Hello", %{})

      assert part.metadata == %{}
    end
  end

  describe "thinking/1" do
    test "creates thinking content part" do
      part = ContentPart.thinking("Let me think about this...")

      assert %ContentPart{type: :thinking, text: "Let me think about this..."} = part
    end

    test "creates thinking with empty string" do
      part = ContentPart.thinking("")

      assert part.type == :thinking
      assert part.text == ""
    end
  end

  describe "thinking/2" do
    test "creates thinking content part with metadata" do
      part = ContentPart.thinking("Reasoning...", %{step: 1})

      assert part.type == :thinking
      assert part.text == "Reasoning..."
      assert part.metadata == %{step: 1}
    end
  end

  describe "image_url/1" do
    test "creates image URL content part" do
      url = "https://example.com/image.png"
      part = ContentPart.image_url(url)

      assert %ContentPart{type: :image_url, url: ^url} = part
    end

    test "creates image URL with data URI" do
      data_uri = "data:image/png;base64,iVBORw0KGgo="
      part = ContentPart.image_url(data_uri)

      assert part.type == :image_url
      assert part.url == data_uri
    end
  end

  describe "image/2" do
    test "creates binary image content part with default media type" do
      binary = <<137, 80, 78, 71, 13, 10, 26, 10>>
      part = ContentPart.image(binary)

      assert part.type == :image
      assert part.data == binary
      assert part.media_type == "image/png"
    end

    test "creates binary image content part with custom media type" do
      binary = <<255, 216, 255, 224>>
      part = ContentPart.image(binary, "image/jpeg")

      assert part.type == :image
      assert part.data == binary
      assert part.media_type == "image/jpeg"
    end

    test "creates image with empty binary" do
      part = ContentPart.image(<<>>)

      assert part.type == :image
      assert part.data == <<>>
    end
  end

  describe "data_uri/1" do
    test "encodes binary images as data URIs" do
      part = ContentPart.image(<<255, 0, 0>>, "image/png")

      assert ContentPart.data_uri(part) == "data:image/png;base64,/wAA"
    end

    test "passes through image URLs unchanged" do
      part = ContentPart.image_url("https://example.com/image.png")

      assert ContentPart.data_uri(part) == "https://example.com/image.png"
    end
  end

  describe "parse_data_uri/1" do
    test "parses valid base64 data URIs" do
      assert {:ok, %{media_type: "image/png", data: <<255, 0, 0>>}} =
               ContentPart.parse_data_uri("data:image/png;base64,/wAA")
    end

    test "returns error for invalid data URIs" do
      assert :error = ContentPart.parse_data_uri("https://example.com/image.png")
      assert :error = ContentPart.parse_data_uri("data:image/png,not-base64")
    end
  end

  describe "file/3" do
    test "creates file content part with default media type" do
      binary = "file contents"
      part = ContentPart.file(binary, "document.pdf")

      assert part.type == :file
      assert part.data == binary
      assert part.filename == "document.pdf"
      assert part.media_type == "application/octet-stream"
    end

    test "creates file content part with custom media type" do
      binary = "csv,data,here"
      part = ContentPart.file(binary, "data.csv", "text/csv")

      assert part.type == :file
      assert part.data == binary
      assert part.filename == "data.csv"
      assert part.media_type == "text/csv"
    end

    test "creates file with empty content" do
      part = ContentPart.file(<<>>, "empty.txt", "text/plain")

      assert part.type == :file
      assert part.data == <<>>
      assert part.filename == "empty.txt"
    end
  end

  describe "document helpers" do
    test "creates document text content parts" do
      part = ContentPart.document_text("Document body", %{title: "Doc"})

      assert part.type == :document
      assert part.data == "Document body"
      assert part.media_type == "text/plain"
      assert part.metadata == %{title: "Doc"}
    end

    test "creates document file references" do
      part = ContentPart.document_file_id("file_123", %{citations: %{enabled: true}})

      assert part.type == :document
      assert part.data == "file_123"
      assert part.metadata.source_type == :file_id
      assert part.metadata.citations == %{enabled: true}
    end

    test "creates search result content parts" do
      part = ContentPart.search_result("Example", "https://example.com", "Body")

      assert part.type == :search_result
      assert part.text == "Body"
      assert part.url == "https://example.com"
      assert part.metadata.title == "Example"
    end
  end

  describe "new/1" do
    test "creates content part from map" do
      {:ok, part} = ContentPart.new(%{type: :text, text: "Hello"})

      assert part.type == :text
      assert part.text == "Hello"
    end

    test "creates content part with string keys" do
      {:ok, part} = ContentPart.new(%{"type" => :text, "text" => "Hello"})

      assert part.type == :text
      assert part.text == "Hello"
    end

    test "returns error for invalid type" do
      {:error, _reason} = ContentPart.new(%{type: :invalid_type})
    end

    test "creates content part with all fields" do
      {:ok, part} =
        ContentPart.new(%{
          type: :image,
          data: <<1, 2, 3>>,
          media_type: "image/gif",
          metadata: %{width: 100}
        })

      assert part.type == :image
      assert part.data == <<1, 2, 3>>
      assert part.media_type == "image/gif"
      assert part.metadata == %{width: 100}
    end
  end

  describe "new!/1" do
    test "creates content part from map" do
      part = ContentPart.new!(%{type: :text, text: "Hello"})

      assert part.type == :text
      assert part.text == "Hello"
    end

    test "raises for invalid attributes" do
      error =
        assert_raise ArgumentError, fn ->
          ContentPart.new!(%{type: :unknown_type})
        end

      assert error.message =~ "Invalid content part"
    end
  end

  describe "valid?/1" do
    test "returns true for valid content parts" do
      assert ContentPart.valid?(ContentPart.text("Hello"))
      assert ContentPart.valid?(ContentPart.thinking("Hmm"))
      assert ContentPart.valid?(ContentPart.image_url("http://example.com/img.png"))
      assert ContentPart.valid?(ContentPart.image(<<1, 2, 3>>))
      assert ContentPart.valid?(ContentPart.file(<<1, 2, 3>>, "file.bin"))
      assert ContentPart.valid?(ContentPart.document_text("Document"))

      assert ContentPart.valid?(
               ContentPart.search_result("Example", "https://example.com", "Body")
             )
    end

    test "returns false for invalid structures" do
      refute ContentPart.valid?(nil)
      refute ContentPart.valid?(%{type: :text, text: "Hello"})
      refute ContentPart.valid?("not a content part")
    end
  end

  describe "schema/0" do
    test "returns Zoi schema" do
      schema = ContentPart.schema()

      assert is_struct(schema)
    end
  end

  describe "Inspect protocol" do
    test "inspects text content part" do
      part = ContentPart.text("Hello, world!")
      result = inspect(part)

      assert result =~ "#ContentPart<"
      assert result =~ ":text"
      assert result =~ "Hello, world!"
    end

    test "inspects thinking content part" do
      part = ContentPart.thinking("Let me think...")
      result = inspect(part)

      assert result =~ ":thinking"
      assert result =~ "Let me think..."
    end

    test "inspects image_url content part" do
      part = ContentPart.image_url("https://example.com/img.png")
      result = inspect(part)

      assert result =~ ":image_url"
      assert result =~ "url:"
      assert result =~ "https://example.com/img.png"
    end

    test "inspects binary image content part" do
      part = ContentPart.image(<<1, 2, 3, 4, 5>>, "image/jpeg")
      result = inspect(part)

      assert result =~ ":image"
      assert result =~ "image/jpeg"
      assert result =~ "5 bytes"
    end

    test "inspects file content part" do
      part = ContentPart.file(<<1, 2, 3>>, "doc.pdf", "application/pdf")
      result = inspect(part)

      assert result =~ ":file"
      assert result =~ "application/pdf"
      assert result =~ "3 bytes"
    end

    test "truncates long text content" do
      long_text = String.duplicate("a", 50)
      part = ContentPart.text(long_text)
      result = inspect(part)

      assert result =~ "..."
      assert result =~ String.duplicate("a", 30)
    end

    test "handles nil text" do
      part = %ContentPart{type: :text, text: nil}
      result = inspect(part)

      assert result =~ "nil"
    end

    test "handles nil file data" do
      part = %ContentPart{type: :file, data: nil, filename: "test.txt"}
      result = inspect(part)

      assert result =~ "0 bytes"
    end
  end

  describe "Jason.Encoder protocol" do
    test "encodes text content part" do
      part = ContentPart.text("Hello")
      json = Jason.encode!(part)
      decoded = Jason.decode!(json)

      assert decoded["type"] == "text"
      assert decoded["text"] == "Hello"
    end

    test "encodes binary data as base64" do
      binary = <<137, 80, 78, 71>>
      part = ContentPart.image(binary, "image/png")
      json = Jason.encode!(part)
      decoded = Jason.decode!(json)

      assert decoded["type"] == "image"
      assert decoded["media_type"] == "image/png"
      assert Base.decode64!(decoded["data"]) == binary
    end

    test "encodes file binary data as base64" do
      binary = "file content"
      part = ContentPart.file(binary, "test.txt", "text/plain")
      json = Jason.encode!(part)
      decoded = Jason.decode!(json)

      assert decoded["type"] == "file"
      assert decoded["filename"] == "test.txt"
      assert Base.decode64!(decoded["data"]) == binary
    end

    test "encodes content part without binary data" do
      part = ContentPart.image_url("https://example.com/img.png")
      json = Jason.encode!(part)
      decoded = Jason.decode!(json)

      assert decoded["type"] == "image_url"
      assert decoded["url"] == "https://example.com/img.png"
      assert decoded["data"] == nil
    end

    test "encodes metadata" do
      part = ContentPart.text("Hello", %{source: "test", version: 1})
      json = Jason.encode!(part)
      decoded = Jason.decode!(json)

      assert decoded["metadata"] == %{"source" => "test", "version" => 1}
    end
  end
end
