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
    case Regex.run(~r/\A```(?:json)?\s*(.*?)\s*```\z/s, text, capture: :all_but_first) do
      [inner] -> inner
      _ -> nil
    end
  end

  defp extract_braced_json(text) do
    case Regex.run(~r/\{.*\}/s, text) do
      [json] -> json
      _ -> nil
    end
  end
end
