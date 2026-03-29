defmodule ReqLlmNext.Wire.GoogleImagesTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.Context
  alias ReqLlmNext.Response
  alias ReqLlmNext.TestModels
  alias ReqLlmNext.Wire.GoogleImages

  test "encodes Gemini image generation bodies with image response modalities" do
    body =
      GoogleImages.encode_body(
        TestModels.google(%{
          id: "gemini-2.5-flash-image",
          capabilities: %{chat: false, embeddings: false},
          modalities: %{input: [:text, :image], output: [:text, :image]}
        }),
        "Draw a paper lantern at dusk",
        n: 2,
        aspect_ratio: "16:9"
      )

    assert body.contents == [%{role: "user", parts: [%{text: "Draw a paper lantern at dusk"}]}]
    assert body.generationConfig.candidateCount == 2
    assert body.generationConfig.responseModalities == ["IMAGE"]
    assert body.generationConfig.imageConfig.aspectRatio == "16:9"
  end

  test "builds Imagen requests against the predict endpoint" do
    {:ok, request} =
      GoogleImages.build_request(
        ReqLlmNext.Providers.Google,
        TestModels.google(%{
          id: "imagen-4.0-fast-generate-001",
          capabilities: %{chat: false, embeddings: false},
          modalities: %{input: [:text], output: [:image]}
        }),
        "Draw a paper lantern at dusk",
        api_key: "test-key",
        output_format: :jpeg,
        size: "1024x1024"
      )

    assert request.scheme == :https
    assert request.host == "generativelanguage.googleapis.com"
    assert request.path == "/v1beta/models/imagen-4.0-fast-generate-001:predict"

    assert Jason.decode!(request.body) == %{
             "instances" => [%{"prompt" => "Draw a paper lantern at dusk"}],
             "parameters" => %{
               "sampleImageSize" => "1K",
               "outputOptions" => %{"mimeType" => "image/jpeg"}
             }
           }
  end

  test "decodes Gemini inline image responses into canonical image parts" do
    response =
      %Finch.Response{
        status: 200,
        headers: [{"content-type", "application/json"}],
        body:
          Jason.encode!(%{
            "candidates" => [
              %{
                "content" => %{
                  "parts" => [
                    %{
                      "inlineData" => %{
                        "mimeType" => "image/png",
                        "data" => Base.encode64(<<1, 2, 3>>)
                      }
                    }
                  ]
                }
              }
            ]
          })
      }

    {:ok, decoded} =
      GoogleImages.decode_response(
        response,
        TestModels.google(%{
          id: "gemini-2.5-flash-image",
          capabilities: %{chat: false, embeddings: false},
          modalities: %{input: [:text, :image], output: [:text, :image]}
        }),
        Context.user("Draw a paper lantern at dusk"),
        []
      )

    assert Response.image_data(decoded) == <<1, 2, 3>>
    assert decoded.finish_reason == :stop
  end

  test "decodes Imagen URI responses into canonical image URL parts" do
    response =
      %Finch.Response{
        status: 200,
        headers: [{"content-type", "application/json"}],
        body:
          Jason.encode!(%{
            "predictions" => [
              %{
                "gcsUri" => "gs://bucket/image.png",
                "mimeType" => "image/png"
              }
            ]
          })
      }

    {:ok, decoded} =
      GoogleImages.decode_response(
        response,
        TestModels.google(%{
          id: "imagen-4.0-fast-generate-001",
          capabilities: %{chat: false, embeddings: false},
          modalities: %{input: [:text], output: [:image]}
        }),
        Context.user("Draw a paper lantern at dusk"),
        []
      )

    assert Response.image_url(decoded) == "gs://bucket/image.png"
    assert hd(Response.images(decoded)).metadata.mime_type == "image/png"
  end
end
