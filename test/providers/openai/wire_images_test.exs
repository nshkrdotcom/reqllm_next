defmodule ReqLlmNext.OpenAI.WireImagesTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Context
  alias ReqLlmNext.Response
  alias ReqLlmNext.SurfacePreparation.OpenAIImages, as: ImagePreparation
  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Wire.OpenAIImages

  test "encodes image generation options into request JSON" do
    body =
      OpenAIImages.encode_body(
        TestModels.openai_image(),
        "Draw a kite",
        size: "1024x1024",
        quality: :high,
        output_format: :png,
        seed: 123
      )

    assert body["model"] == "gpt-image-1"
    assert body["prompt"] == "Draw a kite"
    assert body["n"] == 1
    assert body["size"] == "1024x1024"
    assert body["quality"] == "high"
    assert body["output_format"] == "png"
    assert body["seed"] == 123
  end

  test "extract_prompt preserves separators between text parts in context input" do
    context =
      %Context{
        messages: [
          %ReqLlmNext.Context.Message{
            role: :user,
            content: [
              ReqLlmNext.Context.ContentPart.text("Draw a kite"),
              ReqLlmNext.Context.ContentPart.text("over a lake")
            ]
          }
        ]
      }

    assert {:ok, "Draw a kite\nover a lake"} = ImagePreparation.extract_prompt(context)
  end

  test "decodes an image response into a canonical response" do
    response =
      %Finch.Response{
        status: 200,
        headers: [{"content-type", "application/json"}],
        body:
          Jason.encode!(%{
            "created" => 1_741_234_567,
            "data" => [
              %{
                "b64_json" => Base.encode64(<<1, 2, 3>>),
                "revised_prompt" => "A refined kite prompt"
              }
            ]
          })
      }

    {:ok, decoded} =
      OpenAIImages.decode_response(
        response,
        TestModels.openai_image(),
        Context.user("Draw a kite"),
        output_format: :png
      )

    assert Response.image_data(decoded) == <<1, 2, 3>>
    assert decoded.finish_reason == :stop
    assert hd(Response.images(decoded)).metadata.revised_prompt == "A refined kite prompt"
  end
end
