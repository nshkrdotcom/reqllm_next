defmodule ReqLlmNext.ResponseImagesTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Context
  alias ReqLlmNext.Context.ContentPart
  alias ReqLlmNext.Response
  alias ReqLlmNext.TestModels

  test "extracts image helpers from canonical responses" do
    message = %Context.Message{
      role: :assistant,
      content: [
        ContentPart.image(<<1, 2, 3>>, "image/png"),
        ContentPart.image_url("https://example.com/image.png")
      ]
    }

    response =
      Response.new!(%{
        id: "resp_123",
        model: TestModels.openai_image(),
        context: Context.new([Context.user("Draw a kite"), message]),
        message: message,
        stream?: false,
        stream: nil,
        usage: nil,
        finish_reason: :stop
      })

    assert length(Response.images(response)) == 2
    assert Response.image(response).type == :image
    assert Response.image_data(response) == <<1, 2, 3>>
    assert Response.image_url(response) == "https://example.com/image.png"
  end
end
