defmodule ReqLlmNext.Scenarios.ImageInput do
  @moduledoc """
  Image input modality scenario.

  Tests that models with image input capability can receive and process images.
  Uses a simple test image with known content for validation.
  """

  use ReqLlmNext.Scenario,
    id: :image_input,
    name: "Image Input",
    description: "Image to text processing"

  alias ReqLlmNext.ModelHelpers
  alias ReqLlmNext.Context.ContentPart
  alias ReqLlmNext.ScenarioAssets

  @impl true
  def applies?(model), do: ModelHelpers.supports_image_input?(model)

  @impl true
  def run(model_spec, _model, opts) do
    context =
      ReqLlmNext.context([
        ReqLlmNext.Context.user([
          ContentPart.text(
            "What is the dominant color in this image? Answer with just the color."
          ),
          ContentPart.image(ScenarioAssets.red_square_png())
        ])
      ])

    fixture_opts = run_opts(opts, fixture: fixture_for_run(id(), opts), max_tokens: 100)

    case ReqLlmNext.generate_text(model_spec, context, fixture_opts) do
      {:ok, response} ->
        text = ReqLlmNext.Response.text(response) || ""
        normalized = text |> String.downcase() |> String.trim()

        cond do
          String.length(text) == 0 ->
            error(:empty_response, [
              step("image_describe", :error, response: response, error: :empty_response)
            ])

          String.contains?(normalized, "red") ->
            ok([step("image_describe", :ok, response: response)])

          true ->
            error({:unexpected_description, text}, [
              step("image_describe", :error,
                response: response,
                error: {:unexpected_description, text}
              )
            ])
        end

      {:error, reason} ->
        error(reason, [step("image_describe", :error, error: reason)])
    end
  end
end
