defmodule ReqLlmNext.ObjectDecoder do
  @moduledoc """
  Decodes generated object payloads from raw model text.

  Prompt-and-parse surfaces may wrap otherwise valid JSON in markdown fences or
  surrounding prose. This module extracts the JSON object candidates before
  handing them to Jason.
  """

  @spec decode(String.t()) :: {:ok, map()} | {:error, Exception.t()}
  def decode(json_text) when is_binary(json_text) do
    json_text
    |> json_candidates()
    |> Enum.uniq()
    |> Enum.reduce_while({:error, nil}, fn candidate, _acc ->
      case Jason.decode(candidate) do
        {:ok, object} when is_map(object) ->
          {:halt, {:ok, object}}

        {:ok, _other} ->
          {:cont, {:error, ArgumentError.exception("decoded JSON was not an object")}}

        {:error, error} ->
          {:cont, {:error, error}}
      end
    end)
  end

  defp json_candidates(json_text) do
    trimmed = String.trim(json_text)

    [trimmed, strip_code_fences(trimmed), extract_braced_json(trimmed)]
    |> Enum.reject(&is_nil/1)
  end

  defp strip_code_fences(text) do
    if String.starts_with?(text, "```") and String.ends_with?(text, "```") do
      text
      |> framed_inner()
      |> strip_optional_json_label()
    end
  end

  defp extract_braced_json(text) do
    case {:binary.match(text, "{"), last_match(text, "}")} do
      {{open_index, 1}, {close_index, 1}} when close_index >= open_index ->
        binary_part(text, open_index, close_index - open_index + 1)

      _other ->
        nil
    end
  end

  defp framed_inner(text) do
    text
    |> binary_part(3, byte_size(text) - 6)
    |> String.trim()
  end

  defp strip_optional_json_label(inner) do
    case first_line(inner) do
      {"json", rest} -> String.trim(rest)
      _other -> inner
    end
  end

  defp first_line(text) do
    case :binary.match(text, "\n") do
      {index, 1} ->
        line = binary_part(text, 0, index) |> String.trim()
        rest = binary_part(text, index + 1, byte_size(text) - index - 1)
        {line, rest}

      :nomatch ->
        {String.trim(text), ""}
    end
  end

  defp last_match(text, token) do
    text
    |> :binary.matches(token)
    |> List.last()
  end
end
