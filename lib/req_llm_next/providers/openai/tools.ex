defmodule ReqLlmNext.OpenAI.Tools do
  @moduledoc """
  OpenAI-specific helpers for provider-native built-in tools.
  """

  @provider_native_marker :__provider_native__
  @built_in_tool_types MapSet.new([
                         "web_search",
                         "web_search_preview",
                         "file_search",
                         "code_interpreter",
                         "computer_use",
                         "computer_use_preview",
                         "mcp",
                         "hosted_shell",
                         "apply_patch",
                         "local_shell",
                         "tool_search",
                         "skills",
                         "image_generation"
                       ])

  @spec web_search(keyword()) :: map()
  def web_search(opts \\ []) do
    %{
      @provider_native_marker => :openai,
      type: web_search_type(opts)
    }
    |> maybe_add(:user_location, Keyword.get(opts, :user_location))
    |> maybe_add(:filters, Keyword.get(opts, :filters))
    |> maybe_add(:search_context_size, Keyword.get(opts, :search_context_size))
  end

  @spec file_search(keyword()) :: map()
  def file_search(opts \\ []) do
    %{
      @provider_native_marker => :openai,
      type: "file_search",
      vector_store_ids: Keyword.get(opts, :vector_store_ids, [])
    }
    |> maybe_add(:filters, Keyword.get(opts, :filters))
    |> maybe_add(:max_num_results, Keyword.get(opts, :max_num_results))
  end

  @spec code_interpreter(keyword()) :: map()
  def code_interpreter(opts \\ []) do
    %{
      @provider_native_marker => :openai,
      type: "code_interpreter"
    }
    |> maybe_add(:container, container(opts))
  end

  @spec computer_use(keyword()) :: map()
  def computer_use(opts \\ []) do
    %{
      @provider_native_marker => :openai,
      type: computer_use_type(opts),
      display_width:
        Keyword.get(opts, :display_width, Keyword.get(opts, :display_width_px, 1024)),
      display_height:
        Keyword.get(opts, :display_height, Keyword.get(opts, :display_height_px, 768)),
      environment: Keyword.get(opts, :environment, "browser")
    }
  end

  @spec mcp(keyword()) :: map()
  def mcp(opts \\ []) do
    provider_tool("mcp", opts)
  end

  @spec hosted_shell(keyword()) :: map()
  def hosted_shell(opts \\ []) do
    provider_tool("hosted_shell", opts)
  end

  @spec apply_patch(keyword()) :: map()
  def apply_patch(opts \\ []) do
    provider_tool("apply_patch", opts)
  end

  @spec local_shell(keyword()) :: map()
  def local_shell(opts \\ []) do
    provider_tool("local_shell", opts)
  end

  @spec tool_search(keyword()) :: map()
  def tool_search(opts \\ []) do
    provider_tool("tool_search", opts)
  end

  @spec skill(keyword()) :: map()
  def skill(opts \\ []) do
    provider_tool("skills", opts)
  end

  @spec image_generation(keyword()) :: map()
  def image_generation(opts \\ []) do
    provider_tool("image_generation", opts)
  end

  @spec provider_native_tool?(map()) :: boolean()
  def provider_native_tool?(tool) when is_map(tool) do
    provider_native_marker(tool) == :openai and
      MapSet.member?(@built_in_tool_types, tool_type(tool))
  end

  def provider_native_tool?(_tool), do: false

  @spec encode_provider_native_tool(map()) :: {:ok, map()} | :error
  def encode_provider_native_tool(tool) when is_map(tool) do
    if provider_native_tool?(tool) do
      {:ok, Map.drop(tool, [@provider_native_marker, "__provider_native__"])}
    else
      :error
    end
  end

  @spec web_search_sources_include() :: String.t()
  def web_search_sources_include, do: "web_search_call.action.sources"

  @spec file_search_results_include() :: String.t()
  def file_search_results_include, do: "file_search_call.results"

  defp web_search_type(opts) do
    case Keyword.get(opts, :version, :stable) do
      :preview -> "web_search_preview"
      "preview" -> "web_search_preview"
      _ -> "web_search"
    end
  end

  defp computer_use_type(opts) do
    case Keyword.get(opts, :version, :stable) do
      :preview -> "computer_use_preview"
      "preview" -> "computer_use_preview"
      _ -> "computer_use"
    end
  end

  defp container(opts) do
    case Keyword.get(opts, :container) do
      nil -> container_from_file_ids(Keyword.get(opts, :file_ids))
      :auto -> %{type: "auto"}
      "auto" -> %{type: "auto"}
      container when is_map(container) -> container
      container -> container
    end
  end

  defp container_from_file_ids(file_ids) when is_list(file_ids) and file_ids != [] do
    %{type: "auto", file_ids: file_ids}
  end

  defp container_from_file_ids(_), do: nil

  defp provider_native_marker(tool) do
    Map.get(tool, @provider_native_marker) || Map.get(tool, "__provider_native__")
  end

  defp tool_type(tool) do
    Map.get(tool, :type) || Map.get(tool, "type")
  end

  defp provider_tool(type, opts) when is_binary(type) and is_list(opts) do
    opts
    |> Enum.into(%{@provider_native_marker => :openai, type: type})
  end

  defp maybe_add(map, _key, nil), do: map
  defp maybe_add(map, key, value), do: Map.put(map, key, value)
end
