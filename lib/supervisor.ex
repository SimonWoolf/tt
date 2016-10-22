defmodule TT.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init([]) do
    children = [
      worker(TT.Controller, [:foo]),
      worker(TT.Cli, [:foo])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
