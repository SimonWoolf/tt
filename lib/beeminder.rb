# beeminder gem breaks if we don't require activesupport manually...
require 'active_support'
require 'beeminder'
require 'colorize'
require 'libnotify'

BEEMINDER_TOKEN = ENV['BEEMINDER_TOKEN']

class Beemind < Concurrent::Actor::Context
  def initialize()
    @bee = if BEEMINDER_TOKEN.nil?
      self.parent.tell [:info, ["No beeminder token", :red]]
      nil
    else
      begin
        Beeminder::User.new(BEEMINDER_TOKEN)
      rescue StandardError => e
        self.parent.tell [:info, ["Failed to initialize beeminder: #{e.to_s}", :red]]
        nil
      end
    end
  end

  def on_message(msg)
    case msg
    when :submit_work_pomodoro
      begin
        if @bee
          @bee.send("work", 1, "Submitted by tt #{Time.now}")
          Libnotify.show(body: "Pomodoro submitted", summary: nil, timeout: 5)
        end
      rescue RuntimeError => e
        self.parent.tell [:info, ["Failed to submit pomodoro: #{e.to_s}", :red]]
      end
    end
  end
end
