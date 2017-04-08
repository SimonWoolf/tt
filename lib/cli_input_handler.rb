class CliInputHandler
  def initialize()
    # Set title of the terminal
    system("printf \"\033]0;tt\007\"")
  end

  def get_input()
    STDIN.getch()
  end
end
