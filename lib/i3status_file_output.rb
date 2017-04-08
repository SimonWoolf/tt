require 'color'
require 'json'

class I3statusFileOutput < Concurrent::Actor::Context
  PATH = "/tmp/tt_status"

  def on_message(msg)
    f = File.open(PATH, "w")
    f.write(format(msg))
    f.close()
  end

  def format(msg)
    msg.map do |text, colour|
      {
        full_text: " #{text} ",
        color: to_hex_string(colour),
      }
    end.to_json
  end

  def to_hex_string(colour)
    Color::CSS[colour.to_s.gsub(/_/, '')].html
  end
end
