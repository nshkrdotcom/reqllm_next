defmodule ReqLlmNext.ModelProfile do
  @moduledoc """
  Canonical descriptive runtime profile for a model.
  """

  alias ReqLlmNext.ExecutionSurface
  alias ReqLlmNext.ModelHelpers
  alias ReqLlmNext.Wire.Resolver

  @derive Jason.Encoder

  @schema Zoi.struct(
            __MODULE__,
            %{
              source: Zoi.enum([:llmdb]),
              spec: Zoi.string() |> Zoi.nullish(),
              provider: Zoi.atom(),
              model_id: Zoi.string(),
              family: Zoi.string() |> Zoi.nullish(),
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

  @type operation :: :text | :object | :embed

  @type t :: %__MODULE__{
          source: :llmdb,
          spec: String.t() | nil,
          provider: atom(),
          model_id: String.t(),
          family: String.t() | nil,
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

  defp build_attrs(model, opts) do
    %{
      source: :llmdb,
      spec: Keyword.get(opts, :spec),
      provider: model.provider,
      model_id: model.id,
      family: model.family || get_in(model, [Access.key(:extra, %{}), :family]),
      name: model.name,
      operations: operation_facts(model),
      features: feature_facts(model),
      modalities: model.modalities || %{input: [:text], output: [:text]},
      limits: model.limits || %{},
      parameter_defaults: parameter_defaults(model),
      constraints: get_in(model, [Access.key(:extra, %{}), :constraints]) || %{},
      session_capabilities: session_capabilities(model),
      surfaces: surface_map(model)
    }
  end

  defp operation_facts(model) do
    %{
      text: %{supported: ModelHelpers.chat?(model)},
      object: %{supported: ModelHelpers.chat?(model)},
      embed: %{supported: ModelHelpers.embeddings?(model)}
    }
  end

  defp feature_facts(model) do
    %{
      tools: %{
        supported: ModelHelpers.tools_enabled?(model),
        strict: ModelHelpers.tools_strict?(model),
        parallel: ModelHelpers.tools_parallel?(model)
      },
      structured_outputs: %{
        supported: ModelHelpers.chat?(model),
        native: ModelHelpers.json_schema?(model),
        strategy: object_strategy(model)
      },
      reasoning: %{supported: ModelHelpers.reasoning_enabled?(model)}
    }
  end

  defp parameter_defaults(_model) do
    %{}
  end

  defp session_capabilities(model) do
    if Resolver.responses_api?(model) do
      %{persistent: false, continuation_strategies: []}
    else
      %{persistent: false, continuation_strategies: []}
    end
  end

  defp surface_map(model) do
    %{}
    |> maybe_put_surfaces(:text, text_surfaces(model))
    |> maybe_put_surfaces(:object, object_surfaces(model))
    |> maybe_put_surfaces(:embed, embed_surfaces(model))
  end

  defp maybe_put_surfaces(map, _operation, []), do: map
  defp maybe_put_surfaces(map, operation, surfaces), do: Map.put(map, operation, surfaces)

  defp text_surfaces(model) do
    if ModelHelpers.chat?(model) do
      [chat_surface(model, :text)]
    else
      []
    end
  end

  defp object_surfaces(model) do
    if ModelHelpers.chat?(model) do
      [chat_surface(model, :object)]
    else
      []
    end
  end

  defp embed_surfaces(model) do
    if ModelHelpers.embeddings?(model) do
      [
        ExecutionSurface.new!(%{
          id: :openai_embeddings_embed_http,
          operation: :embed,
          semantic_protocol: :openai_embeddings,
          wire_format: :openai_embeddings_json,
          transport: :http,
          features: %{streaming: false},
          fallback_ids: []
        })
      ]
    else
      []
    end
  end

  defp chat_surface(model, operation) do
    {surface_prefix, semantic_protocol, wire_format} = chat_surface_shape(model)

    ExecutionSurface.new!(%{
      id: surface_id(surface_prefix, operation),
      operation: operation,
      semantic_protocol: semantic_protocol,
      wire_format: wire_format,
      transport: :http_sse,
      features: surface_features(model, operation),
      fallback_ids: []
    })
  end

  defp chat_surface_shape(%LLMDB.Model{provider: :anthropic}) do
    {:anthropic_messages, :anthropic_messages, :anthropic_messages_sse_json}
  end

  defp chat_surface_shape(model) do
    if Resolver.responses_api?(model) do
      {:openai_responses, :openai_responses, :openai_responses_sse_json}
    else
      {:openai_chat, :openai_chat, :openai_chat_sse_json}
    end
  end

  defp surface_id(surface_prefix, operation) do
    :"#{surface_prefix}_#{operation}_http_sse"
  end

  defp surface_features(model, :text) do
    %{
      streaming: ModelHelpers.streaming_text?(model),
      tools: ModelHelpers.tools_enabled?(model),
      reasoning: ModelHelpers.reasoning_enabled?(model),
      structured_output: false
    }
  end

  defp surface_features(model, :object) do
    %{
      streaming: ModelHelpers.streaming_text?(model),
      tools: ModelHelpers.tools_enabled?(model),
      reasoning: ModelHelpers.reasoning_enabled?(model),
      structured_output: object_strategy(model)
    }
  end

  defp object_strategy(model) do
    cond do
      ModelHelpers.json_schema?(model) -> :native_json_schema
      ModelHelpers.chat?(model) -> :prompt_and_parse
      true -> false
    end
  end
end
