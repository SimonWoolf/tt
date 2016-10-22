defmodule TT.Input do
  def spin() do
    char = ExNcurses.getchar
    TT.Cli.input([char])
    spin()
  end
end
