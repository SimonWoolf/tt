class TerminalOutput < Concurrent::Actor::Context
  def on_message(msg)
    clear_screen
    print msg
    crlf
  end

  def clear_screen
    print "\e[H\e[2J"
  end

  # need an explicit carriage return or the cursor stays on the right
  def crlf
    print "\r\n"
  end
end
