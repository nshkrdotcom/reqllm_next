defmodule ReqLlmNext.LiveVerifiers.GoogleTest do
  use ReqLlmNext.TestSupport.LiveVerifierCase, provider: :google

  alias ReqLlmNext.Response

  @text_model "google:gemini-2.5-flash"
  @embedding_model "google:gemini-embedding-001"
  @image_model "google:gemini-2.5-flash-image"
  @object_schema [answer: [type: :string, required: true]]

  test "verifies Gemini baseline text and object lanes" do
    assert {:ok, text_response} =
             ReqLlmNext.generate_text(
               @text_model,
               "Reply with the single word ready.",
               max_tokens: 32
             )

    assert String.downcase(String.trim(Response.text(text_response))) == "ready"

    assert {:ok, object_response} =
             ReqLlmNext.generate_object(
               @text_model,
               "Reply as JSON with an answer field set to ready.",
               @object_schema,
               max_tokens: 128
             )

    assert %{"answer" => answer} = object_response.object
    assert String.downcase(String.trim(answer)) == "ready"
  end

  test "verifies Google embeddings through the public embeddings API" do
    assert {:ok, embedding} =
             ReqLlmNext.embed(@embedding_model, "hello from req llm next")

    assert is_list(embedding)
    assert length(embedding) > 0
    assert Enum.all?(embedding, &is_number/1)
  end

  test "verifies Gemini image generation through the public media API" do
    assert {:ok, response} =
             ReqLlmNext.generate_image(
               @image_model,
               "A simple black triangle on a white background.",
               aspect_ratio: "1:1"
             )

    assert length(Response.images(response)) > 0
    assert is_binary(Response.image_data(response)) or is_binary(Response.image_url(response))
  end
end
