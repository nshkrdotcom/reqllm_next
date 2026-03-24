defmodule ReqLlmNext.OpenAI do
  @moduledoc """
  OpenAI-specific helpers for provider-native built-in tools.
  """

  alias ReqLlmNext.OpenAI.Tools

  @spec web_search_tool(keyword()) :: map()
  def web_search_tool(opts \\ []), do: Tools.web_search(opts)

  @spec file_search_tool(keyword()) :: map()
  def file_search_tool(opts \\ []), do: Tools.file_search(opts)

  @spec code_interpreter_tool(keyword()) :: map()
  def code_interpreter_tool(opts \\ []), do: Tools.code_interpreter(opts)

  @spec computer_use_tool(keyword()) :: map()
  def computer_use_tool(opts \\ []), do: Tools.computer_use(opts)

  @spec web_search_sources_include() :: String.t()
  def web_search_sources_include, do: Tools.web_search_sources_include()

  @spec file_search_results_include() :: String.t()
  def file_search_results_include, do: Tools.file_search_results_include()
end
