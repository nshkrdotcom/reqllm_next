defmodule ReqLlmNext.ScenarioAssets do
  @moduledoc false

  @red_square_png Base.decode64!(
                    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAAXNSR0IArs4c6QAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAEKADAAQAAAABAAAAEAAAAAA0VXHyAAAAHUlEQVQoFWP8z0AaYCJNOQPDqAZiQmw0lAZHKAEAQC4BH9xhSG8AAAAASUVORK5CYII="
                  )

  @spec red_square_png() :: binary()
  def red_square_png, do: @red_square_png
end
