require 'color'
require 'json'

class I3statusFileOutput < Concurrent::Actor::Context
  PATH = "/tmp/tt_status"
  WAYBAR_PATH = "/tmp/tt_waybar_status"

  def on_message(msg)
    f = File.open(PATH, "w")
    f.write(format(msg))
    f.close()

    g = File.open(WAYBAR_PATH, "w")
    g.write(waybar_format(msg))
    g.close()
  end

  def format(msg)
    msg.map do |text, colour|
      {
        full_text: " #{text} ",
        color: to_hex_string(colour),
      }
    end.to_json
  end

  def waybar_format(msg)
    msg.map do |text, colour|
      {
        text: text,
        class: colour
      }
    end[0].to_json
  end

  def to_hex_string(colour)
    {
      red: "#ff9900",
      orange: "#ffcc00",
      darkorange: "#ff8c00",
      yellow: "#ffff00",
    }[colour] ||
      Color::CSS[colour.to_s.gsub(/_/, '')].html
  end
end
