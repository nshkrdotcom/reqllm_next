defmodule ReqLlmNext.PublicApi.SupportStatusTest do
  use ExUnit.Case, async: true

  test "returns first-class for integrated providers" do
    assert ReqLlmNext.support_status("openai:gpt-4o-mini") == :first_class
  end

  test "returns best-effort for packaged providers with typed runtime metadata" do
    model =
      :mistral
      |> LLMDB.models()
      |> Enum.find(&(ReqLlmNext.support_status(&1) == :best_effort))

    assert %LLMDB.Model{} = model
    assert ReqLlmNext.support_status(model) == :best_effort
  end

  test "returns unsupported reasons for catalog-only handcrafted models" do
    model =
      LLMDB.Model.new!(%{
        id: "local-router",
        provider: :router,
        catalog_only: true
      })

    assert ReqLlmNext.support_status(model) == {:unsupported, :catalog_only}
  end

  test "returns unsupported reasons for models missing provider runtime metadata" do
    model =
      LLMDB.Model.new!(%{
        id: "local-router",
        provider: :router,
        execution: %{
          text: %{
            supported: true,
            family: "openai_chat_compatible",
            wire_protocol: "openai_chat",
            path: "/chat/completions"
          }
        }
      })

    assert ReqLlmNext.support_status(model) == {:unsupported, :missing_provider_runtime}
  end
end
