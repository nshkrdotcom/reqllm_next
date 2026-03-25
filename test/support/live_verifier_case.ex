defmodule ReqLlmNext.TestSupport.LiveVerifierCase do
  @moduledoc """
  Case template for sparse opt-in live verifier tests.
  """

  use ExUnit.CaseTemplate

  @live_verifier_env "REQ_LLM_NEXT_RUN_LIVE_VERIFIERS"

  using opts do
    provider = Keyword.fetch!(opts, :provider)
    skip_reason = skip_reason(provider)

    quote bind_quoted: [provider: provider, skip_reason: skip_reason] do
      use ExUnit.Case, async: false

      @moduletag :integration
      @moduletag :live
      @moduletag :live_verifier
      @moduletag live_provider: provider
      @moduletag timeout: 120_000

      if is_binary(skip_reason) do
        @moduletag skip: skip_reason
      end
    end
  end

  @spec skip_reason(atom()) :: String.t() | nil
  def skip_reason(provider) when is_atom(provider) do
    cond do
      not live_verifiers_enabled?() ->
        "set #{@live_verifier_env}=1 to run sparse live verifier tests"

      true ->
        provider
        |> provider_env_key()
        |> missing_key_reason()
    end
  end

  @spec live_verifiers_enabled?() :: boolean()
  def live_verifiers_enabled? do
    System.get_env(@live_verifier_env) in ["1", "true", "TRUE", "yes", "YES"]
  end

  @spec provider_env_key(atom()) :: String.t()
  def provider_env_key(:openai), do: "OPENAI_API_KEY"
  def provider_env_key(:anthropic), do: "ANTHROPIC_API_KEY"
  def provider_env_key(provider), do: "#{provider |> Atom.to_string() |> String.upcase()}_API_KEY"

  defp missing_key_reason(env_key) do
    case System.get_env(env_key) do
      value when is_binary(value) and value != "" -> nil
      _ -> "missing #{env_key} for sparse live verifier tests"
    end
  end
end
