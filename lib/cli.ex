defmodule TT.Cli do
  alias TT.Controller
  use GenServer

  def input(char) do
    GenServer.cast(__MODULE__, {:input, char});
  end

  ##########

  def start_link(args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(args) do
    IO.puts "time tracker"
    ExNcurses.n_begin
    input_receiver = spawn_link(TT.Input, :spin, [])
    {:ok, %{input_receiver: input_receiver}}
  end

  def handle_cast({:input, charlist}, state) do
    ExNcurses.clear
    case charlist do
      'w' ->
        Controller.working!
        ExNcurses.printw "working"
      'b' ->
        Controller.break!
        ExNcurses.printw "break"
      _ ->
        ExNcurses.printw "unknown command"
    end
    {:noreply, state}
  end
end
