defmodule ReqLlmNext.Anthropic.ClientTest do
  use ExUnit.Case, async: false

  alias ReqLlmNext.Anthropic.Client
  alias ReqLlmNext.GovernedAuthority
  alias ReqLlmNext.TestSupport.OpenAIUtilityHarness

  test "json_request uses governed authority for utility URLs and headers" do
    original_key = System.get_env("ANTHROPIC_API_KEY")
    System.put_env("ANTHROPIC_API_KEY", "env-anthropic-key")

    on_exit(fn -> restore_env("ANTHROPIC_API_KEY", original_key) end)

    {:ok, server} =
      OpenAIUtilityHarness.start_server(self(), [
        fn _request ->
          OpenAIUtilityHarness.json_response(200, %{"id" => "msgbatch_123", "type" => "batch"})
        end
      ])

    on_exit(fn -> OpenAIUtilityHarness.stop_server(server) end)

    assert {:ok, %{"id" => "msgbatch_123", "type" => "batch"}} =
             Client.json_request(
               :post,
               "/v1/messages/batches",
               %{requests: []},
               governed_authority: authority(base_url: server.base_url)
             )

    assert_receive {:utility_request, 1, request}
    assert request.request_line == "POST /v1/messages/batches HTTP/1.1"
    assert request.headers["x-api-key"] == nil
    assert request.headers["authorization"] == "governed-credential"
    assert request.headers["anthropic-version"] == "2023-06-01"
    refute inspect(request.headers) =~ "env-anthropic-key"
  end

  defp authority(overrides) do
    defaults = [
      base_url: "https://governed.example",
      credential_ref: "credential://reqllm/anthropic/default",
      credential_lease_ref: "lease://reqllm/anthropic/default",
      provider_key_ref: "provider-key://anthropic/default",
      base_url_ref: "base-url://anthropic/default",
      target_ref: "target://reqllm/anthropic/default",
      operation_policy_ref: "operation-policy://reqllm/anthropic/read",
      cleanup_policy_ref: "cleanup-policy://reqllm/anthropic/default",
      redaction_ref: "redaction://reqllm/default",
      provider_ref: "provider://anthropic",
      provider_account_ref: "provider-account://anthropic/default",
      headers: [{"authorization", "governed-credential"}],
      query: %{},
      template_values: %{}
    ]

    defaults
    |> Keyword.merge(overrides)
    |> GovernedAuthority.new!()
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)
end
