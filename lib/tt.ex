defmodule TT do
  use Application

  def start(_type, _args) do
    TT.Supervisor.start_link
  end
end
