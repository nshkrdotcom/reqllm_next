defmodule ReqLlmNext.OpenAI.BackgroundTest do
  use ExUnit.Case, async: true

  alias ReqLlmNext.OpenAI.Background
  alias ReqLlmNext.TestModels

  test "encodes background responses through the Responses wire" do
    body =
      Background.build_request_body(
        TestModels.openai_reasoning(),
        "Summarize the attached report",
        background: true,
        metadata: %{job: "nightly"},
        service_tier: "flex"
      )

    assert body.background == true
    assert body.metadata == %{job: "nightly"}
    assert body.service_tier == "flex"
    assert body.model == "o1-test"
  end
end
