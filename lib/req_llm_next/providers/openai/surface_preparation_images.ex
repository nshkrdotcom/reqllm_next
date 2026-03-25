defmodule ReqLlmNext.SurfacePreparation.OpenAIImages do
  @moduledoc """
  OpenAI image-generation request preparation.
  """

  alias ReqLlmNext.Context
  alias ReqLlmNext.Error
  alias ReqLlmNext.ExecutionSurface

  @spec prepare(ExecutionSurface.t(), term(), keyword()) :: {:ok, keyword()} | {:error, term()}
  def prepare(%ExecutionSurface{}, prompt, opts) do
    with {:ok, prepared_prompt} <- extract_prompt(prompt) do
      {:ok, Keyword.put(opts, :_prepared_prompt, prepared_prompt)}
    end
  end

  @spec validate(ExecutionSurface.t(), keyword()) :: :ok | {:error, term()}
  def validate(%ExecutionSurface{}, opts) do
    with :ok <- validate_prompt(opts),
         :ok <- validate_no_tools(opts),
         :ok <- validate_no_stream(opts) do
      ReqLlmNext.SurfacePreparation.validate_canonical_inputs(opts)
    end
  end

  defp validate_prompt(opts) do
    case Keyword.get(opts, :_prepared_prompt) do
      prompt when is_binary(prompt) and prompt != "" ->
        :ok

      _ ->
        case extract_prompt(Keyword.get(opts, :_request_input)) do
          {:ok, _prompt} ->
            :ok

          {:error, _} = error ->
            error
        end
    end
  end

  defp validate_no_tools(opts) do
    if Keyword.get(opts, :tools, []) == [] do
      :ok
    else
      {:error,
       Error.Invalid.Parameter.exception(parameter: "image generation does not support tools")}
    end
  end

  defp validate_no_stream(opts) do
    if Keyword.get(opts, :_stream?, false) do
      {:error,
       Error.Invalid.Parameter.exception(parameter: "image generation does not support streaming")}
    else
      :ok
    end
  end

  @spec extract_prompt(String.t() | Context.t() | term()) :: {:ok, String.t()} | {:error, term()}
  def extract_prompt(prompt) when is_binary(prompt) do
    normalized = String.trim(prompt)

    if normalized == "" do
      {:error,
       Error.Invalid.Parameter.exception(
         parameter: "image generation requires a non-empty user text prompt"
       )}
    else
      {:ok, normalized}
    end
  end

  def extract_prompt(%Context{messages: messages}) do
    prompt =
      messages
      |> Enum.reverse()
      |> Enum.find(&(&1.role == :user))
      |> case do
        nil ->
          ""

        %{content: content} when is_list(content) ->
          content
          |> Enum.filter(&(&1.type == :text))
          |> Enum.map(& &1.text)
          |> Enum.reject(&(&1 in [nil, ""]))
          |> Enum.join("\n")

        _ ->
          ""
      end
      |> String.trim()

    extract_prompt(prompt)
  end

  def extract_prompt(_prompt) do
    {:error,
     Error.Invalid.Parameter.exception(
       parameter: "image generation expects a string or ReqLlmNext.Context input"
     )}
  end
end
