require 'colorize'

class TerminalOutput < Concurrent::Actor::Context
  def on_message(msg)
    clear_screen()
    print(format(msg))
    crlf()
  end

  def format(msg)
    msg.map do |text, colour|
      text.send(colour)
    end.join("\r\n")
  end

  def clear_screen
    print "\e[H\e[2J"
  end

  # need an explicit carriage return or the cursor stays on the right
  def crlf
    print "\r\n"
  end
end
