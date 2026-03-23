defmodule ReqLlmNext.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    ReqLlmNext.Env.load()

    children = [
      {Finch, name: ReqLlmNext.Finch}
    ]

    opts = [strategy: :one_for_one, name: ReqLlmNext.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
