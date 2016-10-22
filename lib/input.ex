defmodule TT.Input do
  def spin() do
    ExNcurses.flushinp
    char = ExNcurses.getch
    if(char != -1) do
      IO.puts "Input received"
      TT.CLI.input([char])
    end
    #ExNcurses.refresh
    spin()
  end
end
