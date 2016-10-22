defmodule TT.Controller do
  alias TT.CLI
  use GenServer

  defstruct timer_ref: nil, minutes_in_state: 0, status: :initialized

  def working!() do
    GenServer.cast(__MODULE__, :working)
  end

  def break!() do
    GenServer.cast(__MODULE__, :break)
  end

  #########

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok, %TT.Controller{}}
  end

  def handle_cast(:working, state) do
    case state.status do
      :working ->
        {:noreply, state}
      _ ->
        CLI.show_time_working(0)
        if(state.timer_ref) do
          :erlang.cancel_timer state.timer_ref
        end
        {:noreply, %{state | status: :working, minutes_in_state: 0, timer_ref: set_timeout}}
    end
  end

  def handle_cast(:break, state) do
    {:noreply, state}
  end

  def handle_info(:minute_passed, state) do
    #IO.puts "minute passed"
    new_mis = state.minutes_in_state + 1
    CLI.show_time_working(new_mis)
    {:noreply, %{state | minutes_in_state: new_mis, timer_ref: set_timeout}}
  end

  def handle_info(_, state) do
  end

  defp set_timeout do
    :erlang.send_after one_minute, self, :minute_passed
  end

  defp one_minute do
    Application.get_env :tt, :minute_length
  end
end
