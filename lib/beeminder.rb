# beeminder gem breaks if we don't require activesupport manually...
require 'active_support'
require 'beeminder'
require 'colorize'
require 'libnotify'

BEEMINDER_TOKEN = ENV['BEEMINDER_TOKEN']

class Beemind < Concurrent::Actor::Context
  def initialize()
    if BEEMINDER_TOKEN.nil?
      raise "No beeminder token!"
    else
      @bee = Beeminder::User.new(BEEMINDER_TOKEN)
    end
  end

  def on_message(msg)
    case msg
    when :submit_work_pomodoro
      begin
        @bee.send("work", 1, "Submitted by tt #{Time.now}")
        Libnotify.show(body: "Pomodoro submitted", summary: nil, timeout: 5)
      rescue RuntimeError => e
        self.parent.tell [:info, ["Failed to submit pomodoro: #{e.to_s}", :red]]
      end
    end
  end
end
