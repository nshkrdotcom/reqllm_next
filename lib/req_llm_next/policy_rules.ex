defmodule ReqLlmNext.PolicyRules do
  @moduledoc """
  Resolves a deterministic execution surface and runtime policy from
  `ModelProfile`, `ExecutionMode`, and request overrides.
  """

  alias ReqLlmNext.{Error, ExecutionMode, ExecutionSurface, ModelProfile}

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
  def resolve(%ModelProfile{} = profile, %ExecutionMode{} = mode, opts \\ []) do
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
    case compatible_surfaces(profile, mode) do
      [] ->
        no_surface_error(profile, mode)

      surfaces ->
        {:ok, select_best_surface(surfaces, mode)}
    end
  end

  defp compatible_surfaces(profile, mode) do
    profile
    |> ModelProfile.surfaces_for(mode.operation)
    |> Enum.filter(&surface_matches_mode?(&1, profile, mode))
  end

  defp surface_matches_mode?(surface, profile, mode) do
    transport_supported?(surface, mode) and
      structured_output_supported?(surface, mode) and
      tools_supported?(surface, mode) and
      streaming_supported?(surface, mode) and
      reasoning_supported?(surface, mode) and
      session_supported?(surface, profile, mode)
  end

  defp select_best_surface(surfaces, mode) do
    surfaces
    |> Enum.sort_by(&surface_sort_key(&1, mode), :desc)
    |> hd()
  end

  defp surface_sort_key(surface, mode) do
    [
      session_score(surface, mode),
      transport_score(surface, mode),
      structured_output_score(surface, mode),
      streaming_score(surface, mode),
      reasoning_score(surface, mode),
      fallback_score(surface)
    ]
  end

  defp transport_score(%ExecutionSurface{transport: transport}, %ExecutionMode{
         transport: transport
       }),
       do: 100

  defp transport_score(%ExecutionSurface{transport: :http_sse}, %ExecutionMode{
         transport: :default
       }),
       do: 20

  defp transport_score(%ExecutionSurface{transport: :http}, %ExecutionMode{transport: :default}),
    do: 10

  defp transport_score(%ExecutionSurface{}, %ExecutionMode{}), do: 0

  defp session_score(surface, %ExecutionMode{session: session})
       when session in [:preferred, :required, :continue] do
    if persistent_session?(surface), do: 20, else: 0
  end

  defp session_score(_surface, _mode), do: 0

  defp structured_output_score(surface, %ExecutionMode{structured_output?: true}) do
    if structured_output_available?(surface), do: 15, else: 0
  end

  defp structured_output_score(_surface, _mode), do: 0

  defp streaming_score(surface, %ExecutionMode{stream?: true}) do
    if Map.get(surface.features, :streaming) == true, do: 10, else: 0
  end

  defp streaming_score(_surface, _mode), do: 0

  defp reasoning_score(surface, %ExecutionMode{reasoning: reasoning})
       when reasoning in [:on, :required] do
    if Map.get(surface.features, :reasoning) == true, do: 5, else: 0
  end

  defp reasoning_score(_surface, _mode), do: 0

  defp fallback_score(%ExecutionSurface{fallback_ids: fallback_ids}) when is_list(fallback_ids) do
    -length(fallback_ids)
  end

  defp transport_supported?(_surface, %ExecutionMode{transport: :default}), do: true

  defp transport_supported?(%ExecutionSurface{transport: transport}, %ExecutionMode{
         transport: requested
       }),
       do: transport == requested

  defp structured_output_supported?(_surface, %ExecutionMode{structured_output?: false}), do: true
  defp structured_output_supported?(surface, _mode), do: structured_output_available?(surface)

  defp structured_output_available?(surface) do
    Map.get(surface.features, :structured_output) not in [false, nil]
  end

  defp tools_supported?(_surface, %ExecutionMode{tools?: false}), do: true
  defp tools_supported?(surface, _mode), do: Map.get(surface.features, :tools) == true

  defp streaming_supported?(_surface, %ExecutionMode{stream?: false}), do: true
  defp streaming_supported?(surface, _mode), do: Map.get(surface.features, :streaming) == true

  defp reasoning_supported?(_surface, %ExecutionMode{reasoning: reasoning})
       when reasoning in [:default, :off],
       do: true

  defp reasoning_supported?(surface, _mode), do: Map.get(surface.features, :reasoning) == true

  defp session_supported?(_surface, _profile, %ExecutionMode{session: :none}), do: true
  defp session_supported?(_surface, _profile, %ExecutionMode{session: :preferred}), do: true

  defp session_supported?(surface, profile, %ExecutionMode{session: session})
       when session in [:required, :continue] do
    persistent_session?(surface) and continuation_supported?(profile, session)
  end

  defp persistent_session?(surface) do
    Map.get(surface.features, :persistent_session) == true
  end

  defp continuation_supported?(profile, :continue) do
    profile.session_capabilities[:persistent] == true and
      profile.session_capabilities[:continuation_strategies] != []
  end

  defp continuation_supported?(profile, :required) do
    profile.session_capabilities[:persistent] == true
  end

  defp no_surface_error(profile, %ExecutionMode{transport: transport} = mode)
       when transport in [:http_sse, :websocket] do
    {:error,
     Error.Invalid.Capability.exception(
       message:
         "Model #{profile.model_id} does not support #{inspect(transport)} for #{mode.operation}"
     )}
  end

  defp no_surface_error(profile, %ExecutionMode{session: session})
       when session in [:required, :continue] do
    {:error,
     Error.Invalid.Capability.exception(
       message: "Model #{profile.model_id} does not support persistent sessions"
     )}
  end

  defp no_surface_error(profile, %ExecutionMode{structured_output?: true}) do
    {:error,
     Error.Invalid.Capability.exception(
       message: "Model #{profile.model_id} does not support structured object generation"
     )}
  end

  defp no_surface_error(profile, %ExecutionMode{tools?: true}) do
    {:error,
     Error.Invalid.Capability.exception(
       message: "Model #{profile.model_id} does not support tool calling on the selected surface"
     )}
  end

  defp no_surface_error(profile, %ExecutionMode{reasoning: reasoning})
       when reasoning in [:on, :required] do
    {:error,
     Error.Invalid.Capability.exception(
       message:
         "Model #{profile.model_id} does not support reasoning mode on the selected surface"
     )}
  end

  defp no_surface_error(profile, %ExecutionMode{operation: operation}) do
    {:error,
     Error.Invalid.Capability.exception(
       message: "Model #{profile.model_id} does not support #{operation}"
     )}
  end

  defp timeout_class(%ExecutionMode{latency_class: :long_running}), do: :long_running

  defp timeout_class(%ExecutionMode{reasoning: reasoning})
       when reasoning in [:on, :required], do: :long_running

  defp timeout_class(%ExecutionMode{latency_class: latency_class}), do: latency_class

  defp timeout_ms(_mode, opts) do
    case Keyword.get(opts, :receive_timeout) do
      timeout when is_integer(timeout) and timeout > 0 -> timeout
      _ -> if long_running?(opts), do: @long_running_timeout_ms, else: @default_timeout_ms
    end
  end

  defp long_running?(opts) do
    Keyword.has_key?(opts, :thinking) or Keyword.has_key?(opts, :reasoning_effort)
  end

  defp session_strategy(%ExecutionMode{session: :continue}) do
    %{mode: :continue}
  end

  defp session_strategy(%ExecutionMode{session: :required}) do
    %{mode: :required}
  end

  defp session_strategy(%ExecutionMode{session: :preferred}) do
    %{mode: :preferred}
  end

  defp session_strategy(_mode), do: %{mode: :none}
end
