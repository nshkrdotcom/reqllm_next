defmodule ReqLlmNext.Env do
  @moduledoc """
  Materialized environment boundary for ReqLlmNext.

  Loads a local `.env` file into application config without overriding keys
  that were already materialized by runtime config or the caller.
  """

  @app :req_llm_next
  @key :env

  @spec all(map() | keyword()) :: %{optional(String.t()) => String.t()}
  def all(overrides \\ %{}) do
    configured()
    |> Map.merge(normalize(overrides))
  end

  @spec get(String.t(), map() | keyword() | nil) :: String.t() | nil
  def get(key, env \\ nil)
  def get(key, nil) when is_binary(key), do: Map.get(all(), key)
  def get(key, env) when is_binary(key), do: env |> normalize() |> Map.get(key)

  @spec put(String.t(), term()) :: :ok
  def put(key, value) when is_binary(key) do
    value = to_string(value)
    Application.put_env(@app, @key, Map.put(configured(), key, value))
  end

  @spec delete(String.t()) :: :ok
  def delete(key) when is_binary(key) do
    Application.put_env(@app, @key, Map.delete(configured(), key))
  end

  @spec load(Path.t()) :: :ok
  def load(path \\ ".env") do
    if File.exists?(path) do
      path
      |> File.read!()
      |> String.split("\n")
      |> Enum.each(&load_line/1)
    end

    :ok
  end

  defp load_line(line) do
    line
    |> String.trim()
    |> parse_line()
    |> maybe_put_config()
  end

  defp parse_line(""), do: :skip
  defp parse_line("#" <> _rest), do: :skip
  defp parse_line("export " <> rest), do: parse_line(rest)

  defp parse_line(line) do
    case String.split(line, "=", parts: 2) do
      [key, value] ->
        {:ok, String.trim(key), normalize_value(String.trim(value))}

      _ ->
        :skip
    end
  end

  defp maybe_put_config({:ok, "", _value}), do: :ok

  defp maybe_put_config({:ok, key, value}) do
    unless Map.has_key?(configured(), key) do
      put(key, value)
    end

    :ok
  end

  defp maybe_put_config(:skip), do: :ok

  @spec configured() :: %{optional(String.t()) => String.t()}
  defp configured do
    @app
    |> Application.get_env(@key, %{})
    |> normalize()
  end

  @spec normalize(map() | keyword() | nil) :: %{optional(String.t()) => String.t()}
  defp normalize(env) when is_map(env) do
    env
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new(fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  defp normalize(env) when is_list(env) do
    env
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new(fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  defp normalize(_env), do: %{}

  defp normalize_value("\"" <> rest), do: strip_matching_quote(rest, "\"")
  defp normalize_value("'" <> rest), do: strip_matching_quote(rest, "'")
  defp normalize_value(value), do: value

  defp strip_matching_quote(value, quote) do
    if String.ends_with?(value, quote) do
      value
      |> String.trim_trailing(quote)
    else
      quote <> value
    end
  end
end
