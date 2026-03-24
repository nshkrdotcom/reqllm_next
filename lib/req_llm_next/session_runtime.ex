defmodule ReqLlmNext.SessionRuntime do
  @moduledoc """
  Runtime contract for provider or protocol-specific session handling.
  """

  alias ReqLlmNext.ExecutionPlan

  @callback prepare(ExecutionPlan.t(), keyword(), keyword()) ::
              {:ok, keyword()} | {:error, term()}

  @spec prepare(keyword(), module() | nil, ExecutionPlan.t(), keyword()) ::
          {:ok, keyword()} | {:error, term()}
  def prepare(runtime_opts, nil, %ExecutionPlan{} = _plan, _user_opts) do
    {:ok, runtime_opts}
  end

  def prepare(runtime_opts, module, %ExecutionPlan{} = plan, user_opts)
      when is_atom(module) and is_list(user_opts) and is_list(runtime_opts) do
    module.prepare(plan, user_opts, runtime_opts)
  end
end
