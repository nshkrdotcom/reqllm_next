defmodule ReqLlmNext.ModelProfile do
  @moduledoc """
  Canonical descriptive runtime profile for a model.
  """

  alias ReqLlmNext.ExecutionSurface
  alias ReqLlmNext.ModelHelpers
  alias ReqLlmNext.ModelProfile.ProviderFacts
  alias ReqLlmNext.ModelProfile.SurfaceCatalog

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

  @type operation :: :text | :object | :embed | :image | :transcription | :speech

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
      operations: operation_facts(model, provider_facts),
      features: feature_facts(model, provider_facts),
      modalities: normalize_modalities(model, provider_facts),
      limits: model.limits || %{},
      parameter_defaults: parameter_defaults(model),
      constraints: get_in(model, [Access.key(:extra, %{}), :constraints]) || %{},
      session_capabilities: surface_catalog.session_capabilities,
      surfaces: surface_catalog.surfaces
    }
  end

  defp operation_facts(model, provider_facts) do
    %{
      text: %{supported: chat_supported?(model, provider_facts)},
      object: %{supported: chat_supported?(model, provider_facts)},
      embed: %{supported: embeddings_supported?(model)},
      image: %{supported: ModelHelpers.supports_image_generation?(model)},
      transcription: %{supported: ModelHelpers.supports_transcription?(model)},
      speech: %{supported: ModelHelpers.supports_speech_generation?(model)}
    }
  end

  defp feature_facts(model, provider_facts) do
    %{
      tools: %{
        supported: tools_supported?(model, provider_facts),
        strict: tools_strict?(model),
        parallel: tools_parallel?(model)
      },
      structured_outputs: %{
        supported: chat_supported?(model, provider_facts),
        native: native_structured_outputs?(model, provider_facts),
        strategy: object_strategy(model, provider_facts)
      },
      reasoning: %{supported: reasoning_supported?(model, provider_facts)},
      citations: %{supported: provider_facts.citations_supported?},
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

  defp object_strategy(model, provider_facts) do
    cond do
      native_structured_outputs?(model, provider_facts) -> :native_json_schema
      chat_supported?(model, provider_facts) -> :prompt_and_parse
      true -> false
    end
  end

  defp native_structured_outputs?(model, provider_facts) do
    ModelHelpers.json_schema?(model) or provider_facts.structured_outputs_native?
  end

  defp chat_supported?(_model, %{chat_supported?: value}) when is_boolean(value), do: value
  defp chat_supported?(%LLMDB.Model{capabilities: nil}, _provider_facts), do: true
  defp chat_supported?(model, _provider_facts), do: ModelHelpers.chat?(model)

  defp embeddings_supported?(%LLMDB.Model{capabilities: nil}), do: false
  defp embeddings_supported?(model), do: ModelHelpers.embeddings?(model)

  defp tools_supported?(%LLMDB.Model{capabilities: nil} = model, provider_facts) do
    chat_supported?(model, provider_facts)
  end

  defp tools_supported?(model, _provider_facts), do: ModelHelpers.tools_enabled?(model)

  defp tools_strict?(%LLMDB.Model{capabilities: nil}), do: false
  defp tools_strict?(model), do: ModelHelpers.tools_strict?(model)

  defp tools_parallel?(%LLMDB.Model{capabilities: nil}), do: false
  defp tools_parallel?(model), do: ModelHelpers.tools_parallel?(model)

  defp reasoning_supported?(%LLMDB.Model{capabilities: nil}, _provider_facts), do: false
  defp reasoning_supported?(model, _provider_facts), do: ModelHelpers.reasoning_enabled?(model)

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

  defp normalize_modalities(_model, _provider_facts) do
    %{input: [:text], output: [:text]}
  end
end
