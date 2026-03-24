defmodule ReqLlmNext.ScenarioTestHelpers do
  import ExUnit.Assertions

  alias ReqLlmNext.ToolCall

  def assert_scenario_metadata(module, id, name) do
    assert module.id() == id
    assert module.name() == name
    assert is_binary(module.description())
  end

  def assert_ok_result(result, step_name, step_count \\ 1) do
    assert result.status == :ok
    assert length(result.steps) == step_count
    assert hd(result.steps).name == step_name
  end

  def assert_ok_steps(result, step_names) do
    assert result.status == :ok
    assert Enum.map(result.steps, & &1.name) == step_names
  end

  def validate_text_response(text) do
    cond do
      not is_binary(text) -> %{status: :error, error: :invalid_text_type}
      String.length(text) == 0 -> %{status: :error, error: :empty_response}
      true -> :ok
    end
  end

  def validate_word_limited_text(text, max_words \\ 100) do
    case validate_text_response(text) do
      :ok ->
        word_count = text |> String.split() |> length()

        if word_count <= max_words do
          :ok
        else
          %{status: :error, error: {:token_limit_exceeded, word_count}}
        end

      error ->
        error
    end
  end

  def validate_object_response(object) do
    cond do
      not is_map(object) ->
        %{status: :error, error: :invalid_object_type}

      not Map.has_key?(object, "name") ->
        %{status: :error, error: :missing_name}

      not Map.has_key?(object, "age") ->
        %{status: :error, error: :missing_age}

      not is_binary(object["name"]) or object["name"] == "" ->
        %{status: :error, error: :invalid_name}

      true ->
        :ok
    end
  end

  def validate_no_tool_response(text, tool_calls) do
    cond do
      not is_binary(text) or String.length(text) == 0 ->
        %{status: :error, error: :empty_response}

      tool_calls != [] and Enum.any?(tool_calls, & &1) ->
        %{status: :error, error: :unexpected_tool_calls}

      true ->
        :ok
    end
  end

  def validate_tool_selection(tool_calls, tool_name, required_arg, missing_arg_error) do
    cond do
      not is_list(tool_calls) or tool_calls == [] ->
        %{status: :error, error: :no_tool_calls}

      true ->
        selected_call = Enum.find(tool_calls, fn tc -> ToolCall.name(tc) == tool_name end)

        cond do
          is_nil(selected_call) ->
            %{status: :error, error: :wrong_tool_called}

          true ->
            args = ToolCall.args_map(selected_call)

            if is_map(args) and Map.has_key?(args, required_arg) do
              :ok
            else
              %{status: :error, error: missing_arg_error}
            end
        end
    end
  end

  def validate_parallel_calls(tool_calls, expected_names \\ ["get_time", "get_weather"]) do
    cond do
      not is_list(tool_calls) or length(tool_calls) < 2 ->
        %{status: :error, error: {:expected_multiple_tool_calls, length(tool_calls || [])}}

      true ->
        tool_names = Enum.map(tool_calls, &ToolCall.name/1) |> Enum.sort()

        if Enum.sort(expected_names) == tool_names do
          :ok
        else
          %{status: :error, error: {:wrong_tools_called, tool_names}}
        end
    end
  end

  def validate_tool_round_trip(text, tool_calls, expected_fragment \\ "5") do
    cond do
      text == "" ->
        %{status: :error, error: :empty_final_response}

      not String.contains?(text, expected_fragment) ->
        %{status: :error, error: :result_not_in_response}

      tool_calls != [] ->
        %{status: :error, error: :unexpected_tool_calls}

      true ->
        :ok
    end
  end

  def validate_image_description(text, accepted_terms \\ ["red"]) do
    normalized = text |> String.downcase() |> String.trim()

    cond do
      String.length(text) == 0 ->
        %{status: :error, error: :empty_response}

      Enum.any?(accepted_terms, &String.contains?(normalized, &1)) ->
        :ok

      true ->
        %{status: :error, error: {:unexpected_description, text}}
    end
  end

  def extract_final_answer(text) do
    case Regex.run(~r/FINAL_ANSWER:\s*\$?(\d+)/i, text) do
      [_, num_str] -> {:ok, String.to_integer(num_str)}
      nil -> :no_final_answer
    end
  end

  def validate_reasoning_answer(text, expected_answer \\ 34) do
    case extract_final_answer(text) do
      {:ok, ^expected_answer} ->
        :ok

      {:ok, answer} ->
        {:error, {:incorrect_answer, answer, :expected, expected_answer}}

      :no_final_answer ->
        if String.contains?(text, Integer.to_string(expected_answer)) do
          :ok
        else
          {:error, :no_final_answer_and_no_expected_value}
        end
    end
  end

  def validate_embeddings_result(embeddings_result, expected_count \\ 3) do
    case embeddings_result do
      {:ok, embeddings} when is_list(embeddings) and length(embeddings) == expected_count ->
        :ok

      {:ok, other} ->
        %{status: :error, error: {:unexpected_embedding_format, other}}

      {:error, reason} ->
        %{status: :error, error: reason}
    end
  end

  def valid_embedding?(embedding) do
    is_list(embedding) and
      length(embedding) > 0 and
      Enum.all?(embedding, &is_number/1)
  end

  def cosine_similarity(vec1, vec2) do
    dot_product = Enum.zip(vec1, vec2) |> Enum.reduce(0.0, fn {a, b}, acc -> acc + a * b end)
    magnitude1 = :math.sqrt(Enum.reduce(vec1, 0.0, fn x, acc -> acc + x * x end))
    magnitude2 = :math.sqrt(Enum.reduce(vec2, 0.0, fn x, acc -> acc + x * x end))

    if magnitude1 == 0.0 or magnitude2 == 0.0 do
      0.0
    else
      dot_product / (magnitude1 * magnitude2)
    end
  end
end
