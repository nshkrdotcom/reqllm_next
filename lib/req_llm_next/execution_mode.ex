defmodule ReqLlmNext.ExecutionMode do
  @moduledoc """
  Canonical normalized request-mode object.
  """

  alias ReqLlmNext.Context

  @derive Jason.Encoder

  @schema Zoi.struct(
            __MODULE__,
            %{
              operation: Zoi.enum([:text, :object, :embed]),
              stream?: Zoi.boolean() |> Zoi.default(false),
              tools?: Zoi.boolean() |> Zoi.default(false),
              structured_output?: Zoi.boolean() |> Zoi.default(false),
              transport: Zoi.enum([:default, :http_sse, :websocket]) |> Zoi.default(:default),
              session: Zoi.enum([:none, :preferred, :required, :continue]) |> Zoi.default(:none),
              latency_class:
                Zoi.enum([:interactive, :background, :long_running]) |> Zoi.default(:interactive),
              reasoning: Zoi.enum([:default, :off, :on, :required]) |> Zoi.default(:default),
              conversation: Zoi.enum([:single_turn, :multi_turn]) |> Zoi.default(:single_turn),
              input_modalities: Zoi.array(Zoi.atom()) |> Zoi.default([:text])
            },
            coerce: true
          )

  @type operation :: :text | :object | :embed

  @type t :: %__MODULE__{
          operation: operation(),
          stream?: boolean(),
          tools?: boolean(),
          structured_output?: boolean(),
          transport: :default | :http_sse | :websocket,
          session: :none | :preferred | :required | :continue,
          latency_class: :interactive | :background | :long_running,
          reasoning: :default | :off | :on | :required,
          conversation: :single_turn | :multi_turn,
          input_modalities: [atom()]
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
      {:ok, mode} -> mode
      {:error, reason} -> raise ArgumentError, "Invalid execution mode: #{inspect(reason)}"
    end
  end

  @spec from_request(operation(), String.t() | Context.t() | term(), keyword()) ::
          {:ok, t()} | {:error, term()}
  def from_request(operation, prompt, opts \\ []) do
    new(%{
      operation: operation,
      stream?: Keyword.get(opts, :_stream?, false),
      tools?: tools_present?(opts),
      structured_output?: operation == :object or Keyword.has_key?(opts, :compiled_schema),
      transport: normalize_transport(Keyword.get(opts, :transport, :default)),
      session: normalize_session(Keyword.get(opts, :session, :none)),
      latency_class: normalize_latency(opts),
      reasoning: normalize_reasoning(opts),
      conversation: normalize_conversation(prompt),
      input_modalities: normalize_input_modalities(prompt)
    })
  end

  @spec from_request!(operation(), String.t() | Context.t() | term(), keyword()) :: t()
  def from_request!(operation, prompt, opts \\ []) do
    case from_request(operation, prompt, opts) do
      {:ok, mode} -> mode
      {:error, reason} -> raise ArgumentError, "Invalid execution mode: #{inspect(reason)}"
    end
  end

  defp tools_present?(opts) do
    case Keyword.get(opts, :tools) do
      tools when is_list(tools) and tools != [] -> true
      _ -> false
    end
  end

  defp normalize_session(:required), do: :required
  defp normalize_session(:preferred), do: :preferred
  defp normalize_session(:continue), do: :continue
  defp normalize_session(_), do: :none

  defp normalize_transport(:websocket), do: :websocket
  defp normalize_transport(:http_sse), do: :http_sse
  defp normalize_transport(_), do: :default

  defp normalize_latency(opts) do
    case Keyword.get(opts, :latency_class) do
      latency when latency in [:interactive, :background, :long_running] ->
        latency

      _ ->
        if long_running?(opts) do
          :long_running
        else
          :interactive
        end
    end
  end

  defp long_running?(opts) do
    Keyword.has_key?(opts, :thinking) or
      Keyword.has_key?(opts, :reasoning_effort) or
      Keyword.get(opts, :receive_timeout, 30_000) > 30_000
  end

  defp normalize_reasoning(opts) do
    cond do
      Keyword.get(opts, :reasoning, nil) == :required -> :required
      Keyword.get(opts, :reasoning, nil) == :off -> :off
      Keyword.has_key?(opts, :thinking) -> :on
      Keyword.has_key?(opts, :reasoning_effort) -> :on
      true -> :default
    end
  end

  defp normalize_conversation(%Context{messages: messages}) when length(messages) > 1 do
    :multi_turn
  end

  defp normalize_conversation(%Context{}), do: :single_turn
  defp normalize_conversation(_), do: :single_turn

  defp normalize_input_modalities(%Context{messages: messages}) do
    messages
    |> Enum.flat_map(fn message -> message.content || [] end)
    |> Enum.reduce(MapSet.new([:text]), fn part, acc ->
      case Map.get(part, :type) do
        :image -> MapSet.put(acc, :image)
        :image_url -> MapSet.put(acc, :image)
        :pdf -> MapSet.put(acc, :pdf)
        :audio -> MapSet.put(acc, :audio)
        :document -> MapSet.put(acc, :document)
        :file -> MapSet.put(acc, :document)
        _ -> acc
      end
    end)
    |> MapSet.to_list()
    |> Enum.sort()
  end

  defp normalize_input_modalities(_), do: [:text]
end
