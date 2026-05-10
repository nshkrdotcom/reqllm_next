defmodule ReqLlmNext.Provider do
  @moduledoc """
  Behaviour for LLM provider implementations.

  Providers handle HTTP configuration (base URLs, auth headers, env keys)
  while Wire modules handle encoding/decoding of requests and responses.

  This separation allows:
  - One provider to support multiple wire formats (e.g., OpenAI Chat vs Responses)
  - Wire formats to be reused across providers (e.g., OpenAI-compatible APIs)
  """

  @type auth_header :: {String.t(), String.t()}
  @type request_error :: {:error, term()}

  @callback base_url() :: String.t()
  @callback env_key() :: String.t()
  @callback auth_headers(api_key :: String.t()) :: [auth_header()]
  @callback get_api_key(opts :: keyword()) :: String.t()

  @optional_callbacks []

  alias ReqLlmNext.GovernedAuthority

  defmacro __using__(opts) do
    base_url = Keyword.fetch!(opts, :base_url)
    env_key = Keyword.fetch!(opts, :env_key)
    auth_style = Keyword.get(opts, :auth_style, :bearer)

    quote do
      @behaviour ReqLlmNext.Provider

      @impl ReqLlmNext.Provider
      def base_url, do: unquote(base_url)

      @impl ReqLlmNext.Provider
      def env_key, do: unquote(env_key)

      @impl ReqLlmNext.Provider
      def auth_headers(api_key) do
        ReqLlmNext.Provider.build_auth_headers(unquote(auth_style), api_key)
      end

      @impl ReqLlmNext.Provider
      def get_api_key(opts) do
        case ReqLlmNext.GovernedAuthority.fetch(opts) do
          {:ok, _authority} ->
            raise ReqLlmNext.GovernedAuthority.unmanaged_error(:api_key)

          {:error, reason} ->
            raise reason

          :error ->
            Keyword.get(opts, :api_key) ||
              ReqLlmNext.Env.get(env_key()) ||
              raise "#{env_key()} not set"
        end
      end

      defoverridable base_url: 0, env_key: 0, auth_headers: 1, get_api_key: 1
    end
  end

  def build_auth_headers(:bearer, api_key) do
    [{"Authorization", "Bearer #{api_key}"}]
  end

  def build_auth_headers(:x_api_key, api_key) do
    [{"x-api-key", api_key}]
  end

  @spec base_url(module(), keyword()) :: {:ok, String.t()} | request_error()
  def base_url(provider_mod, opts) do
    case GovernedAuthority.fetch(opts) do
      {:ok, authority} ->
        with :ok <- GovernedAuthority.reject_unmanaged_opts(opts) do
          authority
          |> GovernedAuthority.base_url()
          |> interpolate_values(GovernedAuthority.template_values(authority))
        end

      {:error, _reason} = error ->
        error

      :error ->
        {:ok, Keyword.get(opts, :base_url, provider_mod.base_url())}
    end
  end

  @spec request_url(module(), LLMDB.Model.t(), String.t(), keyword()) ::
          {:ok, String.t()} | request_error()
  def request_url(provider_mod, %LLMDB.Model{} = model, path, opts) when is_binary(path) do
    case GovernedAuthority.fetch(opts) do
      {:ok, authority} ->
        governed_request_url(authority, model, path, opts)

      {:error, _reason} = error ->
        error

      :error ->
        standalone_request_url(provider_mod, model, path, opts)
    end
  end

  @spec request_headers(module(), LLMDB.Model.t(), keyword(), [auth_header()]) ::
          {:ok, [auth_header()]} | request_error()
  def request_headers(provider_mod, %LLMDB.Model{} = _model, opts, extra_headers \\ []) do
    case GovernedAuthority.fetch(opts) do
      {:ok, authority} ->
        governed_request_headers(authority, opts, extra_headers)

      {:error, _reason} = error ->
        error

      :error ->
        standalone_request_headers(provider_mod, opts, extra_headers)
    end
  end

  @spec utility_url(module(), String.t(), keyword()) :: {:ok, String.t()} | request_error()
  def utility_url(provider_mod, path, opts) when is_binary(path) do
    case GovernedAuthority.fetch(opts) do
      {:ok, authority} ->
        with :ok <- reject_absolute_url(path),
             :ok <- GovernedAuthority.reject_unmanaged_opts(opts),
             {:ok, base_url} <-
               authority
               |> GovernedAuthority.base_url()
               |> interpolate_values(GovernedAuthority.template_values(authority)),
             {:ok, resolved_path} <-
               interpolate_values(path, GovernedAuthority.template_values(authority)) do
          {:ok,
           append_query(join_url(base_url, resolved_path), GovernedAuthority.query(authority))}
        end

      {:error, _reason} = error ->
        error

      :error ->
        {:ok, standalone_utility_url(provider_mod, path, opts)}
    end
  end

  @spec utility_headers(module(), keyword(), [auth_header()]) ::
          {:ok, [auth_header()]} | request_error()
  def utility_headers(provider_mod, opts, extra_headers \\ []) do
    case GovernedAuthority.fetch(opts) do
      {:ok, authority} ->
        with :ok <- GovernedAuthority.reject_unmanaged_opts(opts) do
          {:ok, GovernedAuthority.headers(authority) ++ extra_headers}
        end

      {:error, _reason} = error ->
        error

      :error ->
        {:ok, provider_mod.auth_headers(provider_mod.get_api_key(opts)) ++ extra_headers}
    end
  end

  defp standalone_request_url(provider_mod, model, path, opts) do
    if use_runtime_metadata?(opts) do
      with {:ok, runtime} <- fetch_runtime(opts),
           {:ok, base_url} <- resolve_base_url(runtime, model, opts),
           {:ok, resolved_path} <- resolve_path(path, model, opts),
           {:ok, query} <- request_query(runtime, opts) do
        {:ok, append_query(join_url(base_url, resolved_path), query)}
      end
    else
      {:ok, join_url(Keyword.get(opts, :base_url, provider_mod.base_url()), path)}
    end
  end

  defp governed_request_url(authority, model, path, opts) do
    with :ok <- GovernedAuthority.reject_unmanaged_opts(opts),
         {:ok, runtime} <- maybe_fetch_runtime(opts),
         {:ok, base_url} <-
           authority
           |> GovernedAuthority.base_url()
           |> interpolate_values(GovernedAuthority.template_values(authority)),
         {:ok, resolved_path} <- resolve_path(path, model, opts, authority),
         {:ok, query} <- governed_request_query(runtime, authority) do
      {:ok, append_query(join_url(base_url, resolved_path), query)}
    end
  end

  defp standalone_request_headers(provider_mod, opts, extra_headers) do
    if use_runtime_metadata?(opts) do
      with {:ok, runtime} <- fetch_runtime(opts),
           {:ok, auth_headers} <- auth_headers_from_runtime(runtime, opts) do
        {:ok,
         auth_headers ++ map_headers(Map.get(runtime, :default_headers, %{})) ++ extra_headers}
      end
    else
      api_key = provider_mod.get_api_key(opts)
      {:ok, provider_mod.auth_headers(api_key) ++ extra_headers}
    end
  end

  defp governed_request_headers(authority, opts, extra_headers) do
    with :ok <- GovernedAuthority.reject_unmanaged_opts(opts),
         {:ok, runtime} <- maybe_fetch_runtime(opts) do
      default_headers =
        runtime
        |> Map.get(:default_headers, %{})
        |> map_headers()

      {:ok, GovernedAuthority.headers(authority) ++ default_headers ++ extra_headers}
    end
  end

  defp maybe_fetch_runtime(opts) do
    if use_runtime_metadata?(opts), do: fetch_runtime(opts), else: {:ok, %{}}
  end

  defp governed_request_query(runtime, authority) do
    default_query =
      runtime
      |> Map.get(:default_query, %{})
      |> stringify_map()

    {:ok, Map.merge(default_query, GovernedAuthority.query(authority))}
  end

  defp reject_absolute_url(path) do
    if absolute_url?(path) do
      {:error, GovernedAuthority.unmanaged_error(:url)}
    else
      :ok
    end
  end

  defp absolute_url?(path) do
    String.starts_with?(path, "http://") or String.starts_with?(path, "https://")
  end

  defp standalone_utility_url(_provider_mod, "http://" <> _rest = path, _opts), do: path
  defp standalone_utility_url(_provider_mod, "https://" <> _rest = path, _opts), do: path

  defp standalone_utility_url(provider_mod, path, opts) do
    Keyword.get(opts, :base_url, provider_mod.base_url()) <> path
  end

  defp use_runtime_metadata?(opts) do
    Keyword.get(opts, :_use_runtime_metadata, false)
  end

  defp fetch_runtime(opts) do
    case Keyword.get(opts, :_provider_runtime) do
      runtime when is_map(runtime) ->
        {:ok, runtime}

      _other ->
        {:error,
         ReqLlmNext.Error.Invalid.Provider.exception(message: "Missing provider runtime metadata")}
    end
  end

  defp resolve_base_url(runtime, model, opts) do
    execution_entry = Keyword.get(opts, :_model_execution_entry) || %{}

    base_url =
      Keyword.get(opts, :base_url) ||
        Map.get(execution_entry, :base_url) ||
        Map.get(runtime, :base_url)

    if is_binary(base_url) do
      base_url
      |> replace_template("provider_model_id", provider_model_id(model, execution_entry))
      |> interpolate(opts)
    else
      {:error, ReqLlmNext.Error.Invalid.Provider.exception(message: "Missing provider base URL")}
    end
  end

  defp resolve_path(path, model, opts) do
    execution_entry = Keyword.get(opts, :_model_execution_entry) || %{}
    effective_path = Keyword.get(opts, :path) || Map.get(execution_entry, :path) || path

    effective_path
    |> replace_template("provider_model_id", provider_model_id(model, execution_entry))
    |> interpolate(opts)
  end

  defp resolve_path(path, model, opts, %GovernedAuthority{} = authority) do
    execution_entry = Keyword.get(opts, :_model_execution_entry) || %{}
    effective_path = Keyword.get(opts, :path) || Map.get(execution_entry, :path) || path

    effective_path
    |> replace_template("provider_model_id", provider_model_id(model, execution_entry))
    |> interpolate_values(GovernedAuthority.template_values(authority))
  end

  defp request_query(runtime, opts) do
    with {:ok, auth_query} <- auth_query_from_runtime(runtime, opts) do
      default_query = Map.get(runtime, :default_query, %{})
      {:ok, Map.merge(stringify_map(default_query), auth_query)}
    end
  end

  defp auth_headers_from_runtime(%{auth: auth}, opts) when is_map(auth) do
    case Map.get(auth, :type) do
      "bearer" ->
        with {:ok, credential} <- credential(auth, opts) do
          {:ok, [{"Authorization", "Bearer #{credential}"}]}
        end

      "x_api_key" ->
        with {:ok, credential} <- credential(auth, opts) do
          {:ok, [{Map.get(auth, :header_name) || "x-api-key", credential}]}
        end

      "header" ->
        with {:ok, credential} <- credential(auth, opts),
             header_name when is_binary(header_name) <- Map.get(auth, :header_name) do
          {:ok, [{header_name, credential}]}
        else
          _other ->
            {:error,
             ReqLlmNext.Error.Invalid.Provider.exception(
               message: "Invalid provider auth header configuration"
             )}
        end

      "query" ->
        {:ok, []}

      "multi_header" ->
        auth
        |> Map.get(:headers, [])
        |> Enum.reduce_while({:ok, []}, fn header, {:ok, headers} ->
          case resolve_multi_header(header, opts) do
            {:ok, resolved_header} -> {:cont, {:ok, headers ++ [resolved_header]}}
            {:error, _} = error -> {:halt, error}
          end
        end)

      _other ->
        {:error,
         ReqLlmNext.Error.Invalid.Provider.exception(message: "Unsupported provider auth type")}
    end
  end

  defp auth_headers_from_runtime(_runtime, _opts) do
    {:error,
     ReqLlmNext.Error.Invalid.Provider.exception(message: "Missing provider auth metadata")}
  end

  defp auth_query_from_runtime(%{auth: auth}, opts) when is_map(auth) do
    case Map.get(auth, :type) do
      "query" ->
        with {:ok, credential} <- credential(auth, opts),
             query_name when is_binary(query_name) <- Map.get(auth, :query_name) do
          {:ok, %{query_name => credential}}
        else
          _other ->
            {:error,
             ReqLlmNext.Error.Invalid.Provider.exception(
               message: "Invalid provider auth query configuration"
             )}
        end

      _other ->
        {:ok, %{}}
    end
  end

  defp auth_query_from_runtime(_runtime, _opts), do: {:ok, %{}}

  defp credential(auth, opts) do
    envs = Map.get(auth, :env, [])
    value = Keyword.get(opts, :api_key) || Enum.find_value(envs, &ReqLlmNext.Env.get/1)

    if is_binary(value) and value != "" do
      {:ok, value}
    else
      {:error,
       ReqLlmNext.Error.Invalid.Provider.exception(message: "Missing provider API credential")}
    end
  end

  defp resolve_multi_header(header, opts) do
    name = Map.get(header, :name)
    value = Map.get(header, :value) || env_or_nil(Map.get(header, :env))

    if is_binary(name) and is_binary(value) and value != "" do
      {:ok, {name, value}}
    else
      case keyword_lookup_by_name(opts, name) do
        opt_value when is_binary(name) and is_binary(opt_value) and opt_value != "" ->
          {:ok, {name, opt_value}}

        _other ->
          {:error,
           ReqLlmNext.Error.Invalid.Provider.exception(
             message: "Missing provider multi-header credential"
           )}
      end
    end
  end

  defp env_or_nil(env) when is_binary(env), do: ReqLlmNext.Env.get(env)
  defp env_or_nil(_env), do: nil

  defp provider_model_id(model, execution_entry) do
    Map.get(execution_entry, :provider_model_id) || model.provider_model_id || model.id
  end

  defp replace_template(value, _key, nil), do: value

  defp replace_template(value, key, replacement) when is_binary(value) do
    String.replace(value, "{#{key}}", to_string(replacement))
  end

  defp interpolate(value, opts) when is_binary(value) do
    value
    |> template_keys()
    |> Enum.uniq()
    |> Enum.reduce_while({:ok, value}, fn key, {:ok, current} ->
      case lookup_template_value(opts, key) do
        nil ->
          {:halt,
           {:error,
            ReqLlmNext.Error.Invalid.Provider.exception(
              message: "Missing provider runtime configuration for #{key}"
            )}}

        replacement ->
          {:cont, {:ok, String.replace(current, "{#{key}}", to_string(replacement))}}
      end
    end)
  end

  defp interpolate_values(value, values) when is_binary(value) and is_map(values) do
    value
    |> template_keys()
    |> Enum.uniq()
    |> Enum.reduce_while({:ok, value}, fn key, {:ok, current} ->
      case Map.get(values, key) do
        nil ->
          {:halt,
           {:error,
            ReqLlmNext.Error.Invalid.Provider.exception(
              message: "Missing provider runtime configuration for #{key}"
            )}}

        replacement ->
          {:cont, {:ok, String.replace(current, "{#{key}}", to_string(replacement))}}
      end
    end)
  end

  defp lookup_template_value(opts, key) do
    keyword_lookup_by_name(opts, key)
  end

  defp template_keys(value), do: do_template_keys(value, [])

  defp do_template_keys(value, acc) do
    case :binary.match(value, "{") do
      {open_index, 1} ->
        after_open =
          binary_part(value, open_index + 1, byte_size(value) - open_index - 1)

        case :binary.match(after_open, "}") do
          {close_index, 1} ->
            key = binary_part(after_open, 0, close_index)

            rest =
              binary_part(after_open, close_index + 1, byte_size(after_open) - close_index - 1)

            next_acc = if valid_template_key?(key), do: [key | acc], else: acc
            do_template_keys(rest, next_acc)

          :nomatch ->
            Enum.reverse(acc)
        end

      :nomatch ->
        Enum.reverse(acc)
    end
  end

  defp valid_template_key?(<<>>), do: false

  defp valid_template_key?(key) do
    key
    |> :binary.bin_to_list()
    |> Enum.all?(&template_key_byte?/1)
  end

  defp template_key_byte?(byte) when byte in ?a..?z, do: true
  defp template_key_byte?(byte) when byte in ?A..?Z, do: true
  defp template_key_byte?(byte) when byte in ?0..?9, do: true
  defp template_key_byte?(?_), do: true
  defp template_key_byte?(_byte), do: false

  defp keyword_lookup_by_name(opts, name) when is_binary(name) do
    Enum.find_value(opts, fn
      {key, value} when is_atom(key) ->
        if Atom.to_string(key) == name, do: value

      {key, value} when is_binary(key) ->
        if key == name, do: value

      _other ->
        nil
    end)
  end

  defp keyword_lookup_by_name(_opts, _name), do: nil

  defp map_headers(map) when is_map(map) do
    map
    |> stringify_map()
    |> Enum.map(fn {key, value} -> {key, value} end)
  end

  defp stringify_map(map) when is_map(map) do
    Enum.into(map, %{}, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  defp join_url(base_url, path) do
    String.trim_trailing(base_url, "/") <> "/" <> String.trim_leading(path, "/")
  end

  defp append_query(url, query) when map_size(query) == 0, do: url

  defp append_query(url, query) do
    uri = URI.parse(url)
    merged_query = Map.merge(URI.decode_query(uri.query || ""), query)
    %{uri | query: URI.encode_query(merged_query)} |> URI.to_string()
  end
end
