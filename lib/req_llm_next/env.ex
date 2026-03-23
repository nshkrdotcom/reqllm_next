defmodule ReqLlmNext.Env do
  @moduledoc """
  Loads a local `.env` file into the process environment without overriding
  keys that are already set by the shell.
  """

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
    |> maybe_put_env()
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

  defp maybe_put_env({:ok, "", _value}), do: :ok

  defp maybe_put_env({:ok, key, value}) do
    if System.get_env(key) == nil do
      System.put_env(key, value)
    end

    :ok
  end

  defp maybe_put_env(:skip), do: :ok

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
