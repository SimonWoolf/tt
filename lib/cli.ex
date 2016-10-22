defmodule TT.CLI do
  alias TT.Controller
  use GenServer

  def input(char) do
    GenServer.cast(__MODULE__, {:input, char});
  end

  def show_time_working(time) do
    GenServer.cast(__MODULE__, {:show_time_working, time});
  end

  ##########

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(args) do
    ExNcurses.n_begin
    ExNcurses.clear
    ExNcurses.printw "time tracker"
    ExNcurses.noecho
    ExNcurses.cbreak
    input_receiver = spawn_link(TT.Input, :spin, [])
    {:ok, %{input_receiver: input_receiver}}
  end

  def handle_cast({:input, charlist}, state) do
    case charlist do
      'w' ->
        Controller.working!
      'b' ->
        Controller.break!
      _ ->
        ExNcurses.clear
        ExNcurses.printw "unknown command"
    end
    {:noreply, state}
  end

  def handle_cast({:show_time_working, time}, state) do
    #ExNcurses.clear
    #IO.puts "twt #{time}"
    ExNcurses.printw "time working: #{time}\n"
    ExNcurses.refresh
    {:noreply, state}
  end
end
