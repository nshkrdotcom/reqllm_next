defmodule ReqLlmNext.ProviderFeatures.GoogleNativeSurfacesTest do
  use ExUnit.Case, async: false

  alias ReqLlmNext.Fixtures
  alias ReqLlmNext.Response

  @text_model "google:gemini-2.5-flash"
  @embedding_model "google:gemini-embedding-001"
  @gemini_image_model "google:gemini-2.5-flash-image"
  @imagen_model "google:imagen-4.0-fast-generate-001"
  @object_schema [answer: [type: :string, required: true]]

  setup_all do
    LLMDB.load(allow: :all, custom: %{})
    :ok
  end

  test "replays Gemini baseline text generation through the native lane" do
    assert {:ok, response} =
             ReqLlmNext.generate_text(
               @text_model,
               "Reply with the single word ready.",
               fixture: "basic",
               max_tokens: 32
             )

    assert String.downcase(String.trim(Response.text(response))) == "ready"
  end

  test "replays Gemini structured object generation through the native lane" do
    assert {:ok, response} =
             ReqLlmNext.generate_object(
               @text_model,
               "Reply as JSON with an answer field set to ready.",
               @object_schema,
               fixture: "ready_object",
               max_tokens: 128
             )

    assert %{"answer" => answer} = response.object
    assert String.downcase(String.trim(answer)) == "ready"
  end

  test "replays Google embeddings through the public embeddings API" do
    assert {:ok, embedding} =
             ReqLlmNext.embed(
               @embedding_model,
               "hello from req llm next",
               fixture: "embedding"
             )

    assert is_list(embedding)
    assert length(embedding) > 0
    assert Enum.all?(embedding, &is_number/1)

    fixture = load_fixture(@embedding_model, "embedding")
    assert get_in(fixture, ["request", "url"]) =~ ":embedContent"
  end

  test "replays Gemini image generation through the public media API" do
    assert {:ok, response} =
             ReqLlmNext.generate_image(
               @gemini_image_model,
               "A simple black triangle on a white background.",
               fixture: "generate_image_basic",
               aspect_ratio: "1:1"
             )

    assert length(Response.images(response)) > 0
    assert is_binary(Response.image_data(response)) or is_binary(Response.image_url(response))

    fixture = load_fixture(@gemini_image_model, "generate_image_basic")
    assert get_in(fixture, ["request", "url"]) =~ ":generateContent"
  end

  test "replays Imagen generation through the dedicated predict lane" do
    assert {:ok, response} =
             ReqLlmNext.generate_image(
               @imagen_model,
               "A simple black triangle on a white background.",
               fixture: "generate_image_imagen",
               output_format: :png
             )

    assert length(Response.images(response)) > 0
    assert is_binary(Response.image_data(response)) or is_binary(Response.image_url(response))

    fixture = load_fixture(@imagen_model, "generate_image_imagen")
    assert get_in(fixture, ["request", "url"]) =~ ":predict"
  end

  defp load_fixture(model_spec, fixture_name) do
    {:ok, model} = LLMDB.model(model_spec)

    model
    |> Fixtures.path(fixture_name)
    |> File.read!()
    |> Jason.decode!()
  end
end
