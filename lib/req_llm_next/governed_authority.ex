defmodule ReqLlmNext.GovernedAuthority do
  @moduledoc """
  Credential and routing authority supplied by an external governance layer.
  """

  alias ReqLlmNext.Error

  @required_refs [
    :credential_ref,
    :credential_lease_ref,
    :target_ref,
    :operation_policy_ref,
    :redaction_ref
  ]

  @optional_refs [
    :provider_ref,
    :provider_account_ref,
    :model_account_ref,
    :organization_ref,
    :project_ref,
    :realtime_session_ref
  ]

  @unmanaged_keys [
    :api_key,
    :base_url,
    :url,
    :endpoint_url,
    :auth,
    :headers,
    :authorization,
    :realtime_token,
    :session_token,
    :organization_id,
    :org_id,
    :project_id,
    :account_id,
    :provider_account_id,
    :model_account_id
  ]

  @schema Zoi.struct(
            __MODULE__,
            %{
              base_url: Zoi.string(),
              credential_ref: Zoi.string(),
              credential_lease_ref: Zoi.string(),
              target_ref: Zoi.string(),
              operation_policy_ref: Zoi.string(),
              redaction_ref: Zoi.string(),
              provider_ref: Zoi.string() |> Zoi.nullish() |> Zoi.default(nil),
              provider_account_ref: Zoi.string() |> Zoi.nullish() |> Zoi.default(nil),
              model_account_ref: Zoi.string() |> Zoi.nullish() |> Zoi.default(nil),
              organization_ref: Zoi.string() |> Zoi.nullish() |> Zoi.default(nil),
              project_ref: Zoi.string() |> Zoi.nullish() |> Zoi.default(nil),
              realtime_session_ref: Zoi.string() |> Zoi.nullish() |> Zoi.default(nil),
              headers: Zoi.array(Zoi.any()) |> Zoi.default([]),
              query: Zoi.map() |> Zoi.default(%{}),
              template_values: Zoi.map() |> Zoi.default(%{})
            },
            coerce: true
          )

  @type header :: {String.t(), String.t()}

  @type t :: %__MODULE__{
          base_url: String.t(),
          credential_ref: String.t(),
          credential_lease_ref: String.t(),
          target_ref: String.t(),
          operation_policy_ref: String.t(),
          redaction_ref: String.t(),
          provider_ref: String.t() | nil,
          provider_account_ref: String.t() | nil,
          model_account_ref: String.t() | nil,
          organization_ref: String.t() | nil,
          project_ref: String.t() | nil,
          realtime_session_ref: String.t() | nil,
          headers: [header()],
          query: %{optional(String.t()) => String.t()},
          template_values: %{optional(String.t()) => String.t()}
        }

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  @spec new(t() | map() | keyword()) :: {:ok, t()} | {:error, term()}
  def new(%__MODULE__{} = authority), do: validate(authority)

  def new(attrs) when is_list(attrs) do
    attrs
    |> Enum.into(%{})
    |> new()
  end

  def new(attrs) when is_map(attrs) do
    with {:ok, authority} <- Zoi.parse(@schema, attrs) do
      validate(authority)
    end
  end

  @spec new!(t() | map() | keyword()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, authority} -> authority
      {:error, reason} -> raise ArgumentError, "Invalid governed authority: #{inspect(reason)}"
    end
  end

  @spec fetch(keyword()) :: {:ok, t()} | {:error, term()} | :error
  def fetch(opts) when is_list(opts) do
    case Keyword.get(opts, :governed_authority) do
      nil -> :error
      %__MODULE__{} = authority -> {:ok, authority}
      attrs when is_map(attrs) or is_list(attrs) -> new(attrs)
      _other -> {:error, invalid("Invalid governed ReqLlmNext authority")}
    end
  end

  def fetch(_opts), do: :error

  @spec governed?(keyword()) :: boolean()
  def governed?(opts) do
    match?({:ok, _authority}, fetch(opts))
  end

  @spec headers(t()) :: [header()]
  def headers(%__MODULE__{headers: headers}), do: headers

  @spec query(t()) :: %{optional(String.t()) => String.t()}
  def query(%__MODULE__{query: query}), do: query

  @spec template_values(t()) :: %{optional(String.t()) => String.t()}
  def template_values(%__MODULE__{template_values: template_values}), do: template_values

  @spec base_url(t()) :: String.t()
  def base_url(%__MODULE__{base_url: base_url}), do: base_url

  @spec reject_unmanaged_opts(keyword()) :: :ok | {:error, term()}
  def reject_unmanaged_opts(opts) when is_list(opts) do
    case Enum.find(opts, &unmanaged_option?/1) do
      nil -> :ok
      {key, _value} -> {:error, unmanaged_error(key)}
      key -> {:error, unmanaged_error(key)}
    end
  end

  def reject_unmanaged_opts(_opts), do: :ok

  @spec unmanaged_error(atom() | String.t()) :: Exception.t()
  def unmanaged_error(key) do
    Error.Invalid.Provider.exception(
      message: "Cannot use unmanaged #{key_name(key)} with governed ReqLlmNext authority"
    )
  end

  defp validate(%__MODULE__{} = authority) do
    with :ok <- validate_non_empty(:base_url, authority.base_url),
         :ok <- validate_refs(authority, @required_refs, :required),
         :ok <- validate_refs(authority, @optional_refs, :optional),
         {:ok, headers} <- normalize_headers(authority.headers),
         {:ok, query} <- normalize_string_map(authority.query, :query),
         {:ok, template_values} <-
           normalize_string_map(authority.template_values, :template_values) do
      {:ok, %{authority | headers: headers, query: query, template_values: template_values}}
    end
  end

  defp validate_refs(authority, refs, mode) do
    Enum.reduce_while(refs, :ok, fn field, :ok ->
      value = Map.fetch!(authority, field)

      case {mode, value} do
        {:optional, nil} -> {:cont, :ok}
        _other -> reduce_validation(validate_non_empty(field, value))
      end
    end)
  end

  defp reduce_validation(:ok), do: {:cont, :ok}
  defp reduce_validation({:error, _reason} = error), do: {:halt, error}

  defp validate_non_empty(field, value) when is_binary(value) do
    if String.trim(value) == "" do
      {:error, invalid("Missing governed ReqLlmNext authority #{field}")}
    else
      :ok
    end
  end

  defp validate_non_empty(field, _value) do
    {:error, invalid("Missing governed ReqLlmNext authority #{field}")}
  end

  defp normalize_headers(headers) when is_list(headers) do
    Enum.reduce_while(headers, {:ok, []}, fn header, {:ok, acc} ->
      case normalize_header(header) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      error -> error
    end
  end

  defp normalize_headers(_headers) do
    {:error, invalid("Invalid governed ReqLlmNext authority headers")}
  end

  defp normalize_header({name, value}) when is_binary(name) and is_binary(value) do
    if String.trim(name) == "" or value == "" do
      {:error, invalid("Invalid governed ReqLlmNext authority header")}
    else
      {:ok, {name, value}}
    end
  end

  defp normalize_header(_header) do
    {:error, invalid("Invalid governed ReqLlmNext authority header")}
  end

  defp normalize_string_map(map, _field) when is_map(map) do
    {:ok, Enum.into(map, %{}, fn {key, value} -> {to_string(key), to_string(value)} end)}
  end

  defp normalize_string_map(_map, field) do
    {:error, invalid("Invalid governed ReqLlmNext authority #{field}")}
  end

  defp unmanaged_option?({:governed_authority, _value}), do: false

  defp unmanaged_option?({key, _value}) when is_atom(key) do
    key in @unmanaged_keys
  end

  defp unmanaged_option?({key, _value}) when is_binary(key) do
    key in Enum.map(@unmanaged_keys, &Atom.to_string/1)
  end

  defp unmanaged_option?(_option), do: false

  defp key_name(key) when is_atom(key), do: Atom.to_string(key)
  defp key_name(key) when is_binary(key), do: key
  defp key_name(key), do: inspect(key)

  defp invalid(message) do
    Error.Invalid.Provider.exception(message: message)
  end
end
