defmodule ReqLlmNext.EnvTest do
  use ExUnit.Case, async: false

  alias ReqLlmNext.Env

  test "loads values from a local env file" do
    path = temp_env_path()
    File.write!(path, "REQ_LLM_NEXT_ENV_TEST_A=alpha\nREQ_LLM_NEXT_ENV_TEST_B=\"beta value\"\n")

    on_exit(fn ->
      File.rm_rf(path)
      ReqLlmNext.Env.delete("REQ_LLM_NEXT_ENV_TEST_A")
      ReqLlmNext.Env.delete("REQ_LLM_NEXT_ENV_TEST_B")
    end)

    Env.load(path)

    assert ReqLlmNext.Env.get("REQ_LLM_NEXT_ENV_TEST_A") == "alpha"
    assert ReqLlmNext.Env.get("REQ_LLM_NEXT_ENV_TEST_B") == "beta value"
  end

  test "does not override values already present in the shell environment" do
    path = temp_env_path()
    File.write!(path, "REQ_LLM_NEXT_ENV_TEST_C=from_file\n")
    ReqLlmNext.Env.put("REQ_LLM_NEXT_ENV_TEST_C", "from_shell")

    on_exit(fn ->
      File.rm_rf(path)
      ReqLlmNext.Env.delete("REQ_LLM_NEXT_ENV_TEST_C")
    end)

    Env.load(path)

    assert ReqLlmNext.Env.get("REQ_LLM_NEXT_ENV_TEST_C") == "from_shell"
  end

  defp temp_env_path do
    Path.join(System.tmp_dir!(), "req_llm_next_env_#{System.unique_integer([:positive])}.env")
  end
end
