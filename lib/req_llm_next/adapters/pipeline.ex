defmodule ReqLlmNext.Adapters.Pipeline do
  @moduledoc """
  Resolves and executes adapters selected through extension seams.
  """

  @spec adapters_for(LLMDB.Model.t(), [module()]) :: [module()]
  def adapters_for(model, adapter_modules) when is_list(adapter_modules) do
    Enum.filter(adapter_modules, fn adapter_mod ->
      adapter_mod.matches?(model)
    end)
  end

  @spec apply_modules([module()], LLMDB.Model.t(), keyword()) :: keyword()
  def apply_modules(adapter_modules, model, opts) when is_list(adapter_modules) do
    Enum.reduce(adapter_modules, opts, fn adapter_mod, acc_opts ->
      adapter_mod.transform_opts(model, acc_opts)
    end)
  end
end
