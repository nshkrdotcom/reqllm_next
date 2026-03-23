defmodule ReqLlmNext.ExecutionPlan do
  @moduledoc """
  Single prescriptive runtime object for one request attempt.
  """

  alias ReqLlmNext.{ExecutionMode, ExecutionSurface, ModelProfile}

  @derive Jason.Encoder

  @schema Zoi.struct(
            __MODULE__,
            %{
              model: Zoi.any(),
              mode: Zoi.any(),
              surface: Zoi.any(),
              provider: Zoi.atom(),
              semantic_protocol: Zoi.atom(),
              wire_format: Zoi.atom(),
              transport: Zoi.atom(),
              parameter_values: Zoi.map() |> Zoi.default(%{}),
              timeout_class:
                Zoi.enum([:interactive, :background, :long_running]) |> Zoi.default(:interactive),
              timeout_ms: Zoi.integer() |> Zoi.default(30_000),
              session_strategy: Zoi.map() |> Zoi.default(%{mode: :none}),
              fallback_surfaces: Zoi.array(Zoi.atom()) |> Zoi.default([]),
              plan_adapters: Zoi.array(Zoi.any()) |> Zoi.default([])
            },
            coerce: true
          )

  @type t :: %__MODULE__{
          model: ModelProfile.t(),
          mode: ExecutionMode.t(),
          surface: ExecutionSurface.t(),
          provider: atom(),
          semantic_protocol: atom(),
          wire_format: atom(),
          transport: atom(),
          parameter_values: map(),
          timeout_class: :interactive | :background | :long_running,
          timeout_ms: non_neg_integer(),
          session_strategy: map(),
          fallback_surfaces: [atom()],
          plan_adapters: [module()]
        }

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs) do
    Zoi.parse(@schema, attrs)
  end

  @spec new!(map()) :: t()
  def new!(attrs) when is_map(attrs) do
    case new(attrs) do
      {:ok, plan} -> plan
      {:error, reason} -> raise ArgumentError, "Invalid execution plan: #{inspect(reason)}"
    end
  end
end
