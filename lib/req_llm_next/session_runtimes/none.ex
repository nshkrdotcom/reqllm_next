defmodule ReqLlmNext.SessionRuntimes.None do
  @moduledoc false

  @behaviour ReqLlmNext.SessionRuntime

  @impl ReqLlmNext.SessionRuntime
  def prepare(_plan, _user_opts, runtime_opts), do: {:ok, runtime_opts}
end
