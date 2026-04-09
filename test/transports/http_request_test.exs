defmodule ReqLlmNext.Transports.HTTPRequestTest do
  use ExUnit.Case, async: false

  alias ReqLlmNext.Error
  alias ReqLlmNext.TestModels
  alias ReqLlmNext.TestSupport.OpenAIUtilityHarness
  alias ReqLlmNext.Transports.HTTPRequest

  defmodule DummyProvider do
  end

  defmodule DummyWire do
    def build_request(_provider_mod, _model, input, opts) do
      {:ok,
       Finch.build(
         :post,
         Keyword.fetch!(opts, :url),
         [{"content-type", "application/json"}],
         Jason.encode!(%{input: input})
       )}
    end

    def decode_response(%Finch.Response{} = response, _model, _input, _opts) do
      Jason.decode(response.body)
    end
  end

  test "request/5 executes unary HTTP through the execution plane and decodes the response" do
    {:ok, server} =
      OpenAIUtilityHarness.start_server(self(), [
        fn request ->
          assert request.request_line == "POST /chat HTTP/1.1"
          assert request.body == ~s({"input":"hello"})
          OpenAIUtilityHarness.json_response(200, %{"ok" => true})
        end
      ])

    on_exit(fn -> OpenAIUtilityHarness.stop_server(server) end)

    assert {:ok, %{"ok" => true}} =
             HTTPRequest.request(
               DummyProvider,
               DummyWire,
               TestModels.openai(),
               "hello",
               url: server.base_url <> "/chat"
             )
  end

  test "request/5 keeps transport failures distinct from semantic HTTP failures" do
    {:ok, server} =
      OpenAIUtilityHarness.start_server(self(), [
        fn _request ->
          Process.sleep(150)
          OpenAIUtilityHarness.json_response(200, %{"ok" => true})
        end
      ])

    on_exit(fn -> OpenAIUtilityHarness.stop_server(server) end)

    assert {:error, %Error.API.Request{} = error} =
             HTTPRequest.request(
               DummyProvider,
               DummyWire,
               TestModels.openai(),
               "hello",
               url: server.base_url <> "/slow",
               timeout: 10
             )

    assert error.status == nil
    assert String.contains?(error.reason, "HTTP transport failed")
  end
end
