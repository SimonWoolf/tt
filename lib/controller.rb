require 'colorize'
require_relative 'beeminder'

PERIOD_SECS = 5
PERIODS_PER_POMODORO = (25 * 60) / PERIOD_SECS
PERIODS_PER_BREAK = (5 * 60) / PERIOD_SECS

def periods_to_minutes(periods)
  (periods * PERIOD_SECS) / 60
end

def p(str)
  puts(str + "\r")
end

class Controller < Concurrent::Actor::Context
  def initialize()
    @bee = Beemind.spawn(:bee)

    @timer = Concurrent::TimerTask.new(execution_interval: PERIOD_SECS, run_now: true) {
      self.tell(:tick)
    }
    @timer.execute

    @state = {
      status: :initialized,
      periods_in_state: 0,
      work_pomodoro_periods: 0,
      prompt: nil
    }
  end

  def on_message(msg, payload=nil)
    case msg
    when :tick
      on_tick
      show_update

    when :working, :break, :procrastinating
      set_status(msg)

    when :info
      @state[:prompt] << "\n"
      @state[:prompt] << payload
      show_update

    when Array
      on_message(msg[0], msg[1])
    end
  end

  def set_status(msg)
    if status != msg
      @state[:status] = msg
      @state[:periods_in_state] = 0
      @state[:prompt] = nil
      show_update
    end
  end

  def show_update()
    cls

    if initialized?
      p "time tracker".white.bold
    else
      p "#{@state[:status]}: #{periods_to_minutes(@state[:periods_in_state])} minutes".bold.send(state_color)
    end

    if prompt
      p prompt
    end
  end

  def on_tick
    @state[:periods_in_state] += 1

    if working?
      @state[:work_pomodoro_periods] += 1
    end

    if work_pomodoro_periods >= PERIODS_PER_POMODORO
      @bee.tell(:submit_work_pomodoro)
      @state[:work_pomodoro_periods] = 0
    end

    if working? && periods_in_state >= PERIODS_PER_POMODORO && !prompt
      @state[:prompt] = "Take a break".bold.white
    elsif break? && periods_in_state >= PERIODS_PER_BREAK && !prompt
      @state[:prompt] = "Break over".bold.white
    end
  end

  def cls
    print "\e[H\e[2J"
  end

  def method_missing(method, *args, &block)
    if method[-1] == ??
      @state[:status] == method[0..-2].to_sym
    elsif @state[method]
      @state[method]
    end
  end

  def state_color
    {
      initialized: :white,
      working: :light_green,
      break: :light_blue
    }[@state[:status]]
  end
end

