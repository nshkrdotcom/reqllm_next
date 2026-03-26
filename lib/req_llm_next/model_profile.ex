defmodule ReqLlmNext.ModelProfile do
  @moduledoc """
  Canonical descriptive runtime profile for a model.
  """

  alias ReqLlmNext.ExecutionSurface
  alias ReqLlmNext.ModelHelpers
  alias ReqLlmNext.ModelProfile.ProviderFacts
  alias ReqLlmNext.ModelProfile.SurfaceCatalog
  alias ReqLlmNext.RuntimeMetadata

  @derive Jason.Encoder

  @schema Zoi.struct(
            __MODULE__,
            %{
              source: Zoi.enum([:llmdb]),
              spec: Zoi.string() |> Zoi.nullish(),
              provider: Zoi.atom(),
              model_id: Zoi.string(),
              family: Zoi.atom() |> Zoi.nullish(),
              name: Zoi.string() |> Zoi.nullish(),
              operations: Zoi.map() |> Zoi.default(%{}),
              features: Zoi.map() |> Zoi.default(%{}),
              modalities: Zoi.map() |> Zoi.default(%{}),
              limits: Zoi.map() |> Zoi.default(%{}),
              parameter_defaults: Zoi.map() |> Zoi.default(%{}),
              constraints: Zoi.map() |> Zoi.default(%{}),
              session_capabilities: Zoi.map() |> Zoi.default(%{}),
              surfaces: Zoi.map() |> Zoi.default(%{})
            },
            coerce: true
          )

  @type operation :: :text | :object | :embed | :image | :transcription | :speech | :realtime

  @type t :: %__MODULE__{
          source: :llmdb,
          spec: String.t() | nil,
          provider: atom(),
          model_id: String.t(),
          family: atom() | nil,
          name: String.t() | nil,
          operations: map(),
          features: map(),
          modalities: map(),
          limits: map(),
          parameter_defaults: map(),
          constraints: map(),
          session_capabilities: map(),
          surfaces: %{optional(operation()) => [ExecutionSurface.t()]}
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
      {:ok, profile} -> profile
      {:error, reason} -> raise ArgumentError, "Invalid model profile: #{inspect(reason)}"
    end
  end

  @spec from_model(LLMDB.Model.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def from_model(%LLMDB.Model{} = model, opts \\ []) do
    new(build_attrs(model, opts))
  end

  @spec from_model!(LLMDB.Model.t(), keyword()) :: t()
  def from_model!(%LLMDB.Model{} = model, opts \\ []) do
    case from_model(model, opts) do
      {:ok, profile} -> profile
      {:error, reason} -> raise ArgumentError, "Invalid model profile: #{inspect(reason)}"
    end
  end

  @spec surfaces_for(t(), operation()) :: [ExecutionSurface.t()]
  def surfaces_for(%__MODULE__{surfaces: surfaces}, operation) when is_atom(operation) do
    Map.get(surfaces, operation, [])
  end

  @spec supports_operation?(t(), operation()) :: boolean()
  def supports_operation?(%__MODULE__{operations: operations}, operation)
      when is_atom(operation) do
    get_in(operations, [operation, :supported]) == true
  end

  @spec feature_supported?(t(), atom()) :: boolean()
  def feature_supported?(%__MODULE__{features: features}, feature) when is_atom(feature) do
    get_in(features, [feature, :supported]) == true
  end

  @spec input_modalities(t()) :: [atom()]
  def input_modalities(%__MODULE__{modalities: modalities}) do
    get_in(modalities, [:input]) || [:text]
  end

  @spec supports_streaming?(t(), operation()) :: boolean()
  def supports_streaming?(%__MODULE__{} = profile, operation) when is_atom(operation) do
    profile
    |> surfaces_for(operation)
    |> Enum.any?(&(Map.get(&1.features, :streaming) == true))
  end

  defp build_attrs(model, opts) do
    provider_facts = ProviderFacts.extract(model)
    surface_catalog = SurfaceCatalog.build(model, provider_facts)

    %{
      source: :llmdb,
      spec: Keyword.get(opts, :spec),
      provider: model.provider,
      model_id: model.id,
      family: surface_catalog.family,
      name: model.name,
      operations: operation_facts(model, surface_catalog),
      features: feature_facts(model, provider_facts, surface_catalog),
      modalities: normalize_modalities(model, provider_facts),
      limits: model.limits || %{},
      parameter_defaults: parameter_defaults(model),
      constraints: get_in(model, [Access.key(:extra, %{}), :constraints]) || %{},
      session_capabilities: surface_catalog.session_capabilities,
      surfaces: surface_catalog.surfaces
    }
  end

  defp operation_facts(model, surface_catalog) do
    %{
      text: %{supported: surfaces_supported?(surface_catalog, :text)},
      object: %{supported: surfaces_supported?(surface_catalog, :object)},
      embed: %{supported: surfaces_supported?(surface_catalog, :embed)},
      image: %{supported: surfaces_supported?(surface_catalog, :image)},
      transcription: %{supported: surfaces_supported?(surface_catalog, :transcription)},
      speech: %{supported: surfaces_supported?(surface_catalog, :speech)},
      realtime: %{supported: execution_supported?(model, :realtime)}
    }
  end

  defp feature_facts(model, provider_facts, surface_catalog) do
    object_strategy = object_strategy(surface_catalog)

    %{
      tools: %{
        supported: surface_feature_supported?(surface_catalog, :tools),
        strict: tools_strict?(model),
        parallel: tools_parallel?(model)
      },
      structured_outputs: %{
        supported: object_strategy not in [false, nil],
        native: object_strategy == :native_json_schema,
        strategy: object_strategy
      },
      reasoning: %{supported: surface_feature_supported?(surface_catalog, :reasoning)},
      citations: %{
        supported:
          provider_facts.citations_supported? or
            surface_feature_supported?(surface_catalog, :citations)
      },
      context_management: %{supported: provider_facts.context_management_supported?},
      document_input: %{
        supported:
          ModelHelpers.supports_pdf_input?(model) or provider_facts.additional_document_input?
      }
    }
  end

  defp parameter_defaults(_model) do
    %{}
  end

  defp object_strategy(surface_catalog) do
    surface_feature(surface_catalog, :object, :structured_output) || false
  end

  defp tools_strict?(%LLMDB.Model{capabilities: nil}), do: false
  defp tools_strict?(model), do: ModelHelpers.tools_strict?(model)

  defp tools_parallel?(%LLMDB.Model{capabilities: nil}), do: false
  defp tools_parallel?(model), do: ModelHelpers.tools_parallel?(model)

  defp normalize_modalities(%LLMDB.Model{modalities: modalities}, _provider_facts)
       when is_map(modalities) do
    modalities
  end

  defp normalize_modalities(_model, %{media_api: :transcription}) do
    %{input: [:audio], output: [:text]}
  end

  defp normalize_modalities(_model, %{media_api: :speech}) do
    %{input: [:text], output: [:audio]}
  end

  defp normalize_modalities(_model, %{media_api: :images}) do
    %{input: [:text], output: [:image]}
  end

  defp normalize_modalities(%LLMDB.Model{} = model, _provider_facts) do
    cond do
      execution_supported?(model, :transcription) ->
        %{input: [:audio], output: [:text]}

      execution_supported?(model, :speech) ->
        %{input: [:text], output: [:audio]}

      execution_supported?(model, :image) ->
        %{input: [:text], output: [:image]}

      execution_supported?(model, :embed) and not execution_supported?(model, :text) ->
        %{input: [:text], output: [:embedding]}

      true ->
        %{input: [:text], output: [:text]}
    end
  end

  defp surfaces_supported?(surface_catalog, operation) do
    surface_catalog
    |> Map.get(:surfaces, %{})
    |> Map.get(operation, [])
    |> case do
      [] -> false
      _surfaces -> true
    end
  end

  defp surface_feature_supported?(surface_catalog, feature) do
    surface_catalog
    |> Map.get(:surfaces, %{})
    |> Map.values()
    |> List.flatten()
    |> Enum.any?(&(Map.get(&1.features, feature) == true))
  end

  defp surface_feature(surface_catalog, operation, feature) do
    surface_catalog
    |> Map.get(:surfaces, %{})
    |> Map.get(operation, [])
    |> Enum.find_value(&Map.get(&1.features, feature))
  end

  defp execution_supported?(model, operation) do
    match?({:ok, _entry}, RuntimeMetadata.execution_entry(model, operation))
  end
end
