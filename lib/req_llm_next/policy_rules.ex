defmodule ReqLlmNext.PolicyRules do
  @moduledoc """
  Minimal policy selection bridge for the first planning slice.
  """

  alias ReqLlmNext.{ExecutionSurface, ModelProfile}

  @default_timeout_ms 30_000
  @long_running_timeout_ms 300_000

  @type selection :: %{
          required(:surface) => ExecutionSurface.t(),
          required(:fallback_surfaces) => [atom()],
          required(:timeout_class) => :interactive | :background | :long_running,
          required(:timeout_ms) => non_neg_integer(),
          required(:session_strategy) => map()
        }

  @spec resolve(ModelProfile.t(), ReqLlmNext.ExecutionMode.t(), keyword()) ::
          {:ok, selection()} | {:error, term()}
  def resolve(%ModelProfile{} = profile, %ReqLlmNext.ExecutionMode{} = mode, opts \\ []) do
    with {:ok, surface} <- select_surface(profile, mode) do
      {:ok,
       %{
         surface: surface,
         fallback_surfaces: surface.fallback_ids,
         timeout_class: timeout_class(mode),
         timeout_ms: timeout_ms(mode, opts),
         session_strategy: session_strategy(mode)
       }}
    end
  end

  defp select_surface(profile, mode) do
    case ModelProfile.surfaces_for(profile, mode.operation) do
      [] ->
        {:error, {:unsupported_operation, profile.model_id, mode.operation}}

      surfaces ->
        {:ok, prefer_surface(surfaces, mode)}
    end
  end

  defp prefer_surface(surfaces, %ReqLlmNext.ExecutionMode{structured_output?: true}) do
    Enum.find(surfaces, hd(surfaces), fn surface ->
      Map.get(surface.features, :structured_output) not in [false, nil]
    end)
  end

  defp prefer_surface(surfaces, %ReqLlmNext.ExecutionMode{transport: transport} = mode)
       when transport in [:http_sse, :websocket] do
    surfaces
    |> Enum.filter(&(&1.transport == transport))
    |> case do
      [] -> prefer_surface(surfaces, %{mode | transport: :default})
      matching -> prefer_surface(matching, %{mode | transport: :default})
    end
  end

  defp prefer_surface(surfaces, _mode), do: hd(surfaces)

  defp timeout_class(%ReqLlmNext.ExecutionMode{latency_class: :long_running}), do: :long_running

  defp timeout_class(%ReqLlmNext.ExecutionMode{reasoning: reasoning})
       when reasoning in [:on, :required], do: :long_running

  defp timeout_class(%ReqLlmNext.ExecutionMode{latency_class: latency_class}), do: latency_class

  defp timeout_ms(_mode, opts) do
    case Keyword.get(opts, :receive_timeout) do
      timeout when is_integer(timeout) and timeout > 0 -> timeout
      _ -> if long_running?(opts), do: @long_running_timeout_ms, else: @default_timeout_ms
    end
  end

  defp long_running?(opts) do
    Keyword.has_key?(opts, :thinking) or Keyword.has_key?(opts, :reasoning_effort)
  end

  defp session_strategy(%ReqLlmNext.ExecutionMode{session: :continue}) do
    %{mode: :continue}
  end

  defp session_strategy(%ReqLlmNext.ExecutionMode{session: :required}) do
    %{mode: :required}
  end

  defp session_strategy(%ReqLlmNext.ExecutionMode{session: :preferred}) do
    %{mode: :preferred}
  end

  defp session_strategy(_mode), do: %{mode: :none}
end
