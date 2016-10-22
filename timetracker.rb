require 'io/console'
require 'concurrent-edge'
ONE_MINUTE = 1

class Controller < Concurrent::Actor::Context
  def initialize()
    @state = {
      status: :initialized,
      minutes_in_state: 0,
      work_pomodoro_minutes: 0
    }
  end

  def on_message(msg)
    puts "state: #{@state.inspect}"
    case msg
    when :tick
      @state[:minutes_in_state] += 1
      show_update "tick"

    when :working
      @state[:status] = :working
      @state[:minutes_in_state] = 0
      show_update "working"

    when :break
      @state[:status] = :break
      @state[:minutes_in_state] = 0
      show_update "break"
    end
  end

  def show_update(string)
    cls
    puts "#{@state[:status]}: #{@state[:minutes_in_state]}"
  end

  def cls
    print "\e[H\e[2J"
  end
end

controller = Controller.spawn(:controller)

timer = Concurrent::TimerTask.new(execution_interval: ONE_MINUTE, run_now: true) {
  controller.tell(:tick)
}
timer.execute

puts "time tracker"

loop do
  case STDIN.getch
  when "\u0003"
    exit
  when ?q
    exit
  when ?w
    controller.tell(:working)
  when ?b
    controller.tell(:break)
    puts "break"
  end
end
