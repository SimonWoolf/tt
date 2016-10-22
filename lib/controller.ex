defmodule TT.Controller do
  use GenServer

  def working!() do
    GenServer.cast(__MODULE__, :working)
  end

  def break!() do
    GenServer.cast(__MODULE__, :working)
  end

  #########

  def start_link(args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(args) do
    {:ok, :state}
  end

  def handle_cast(:working, state) do
    {:noreply, state}
  end

  def handle_cast(:break, state) do
    IO.puts "\n\n\n\n\ofietnoipenf"
    {:noreply, state}
  end
end
