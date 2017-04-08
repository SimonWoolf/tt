require_relative 'beeminder'

PERIOD_SECS = 5
PERIODS_PER_POMODORO = (25 * 60) / PERIOD_SECS
PERIODS_PER_BREAK = (5 * 60) / PERIOD_SECS
DING_SOUND = '/home/simon/dev/dotfiles/pomodoro-finish.wav'
DING_SPEED = 5
SLOW_DING_SPEED = 2
MAX_DAILY_POMODOROS = 14

def periods_to_minutes(periods)
  (periods * PERIOD_SECS) / 60
end

class Controller < Concurrent::Actor::Context
  def initialize(options)
    @timer = Concurrent::TimerTask.new(execution_interval: PERIOD_SECS, run_now: true) do
      self.tell(:tick)
    end
    @timer.execute

    @status = :initialized
    @mode = options[:mode] || :internet
    @periods_in_state = 0
    @work_pomodoro_periods = 0
    @unsubmitted_work_pomodoros = 0
    @work_pomodoros_done_today = 0
    @prompt = []

    if @mode == :internet
      @bee = Beemind.spawn(:bee)
    end

    @outputs = options[:outputs].map do |output|
      output.spawn(output.to_s)
    end
  end

  def on_message(msg, payload=nil)
    case msg
    when :tick
      on_tick
      show_update

    when :working, :break, :procrastinating, :non_work
      set_status(msg)

    when :refresh
      show_update

    when :info
      @prompt = [payload]
      show_update

    when :local_mode
      @mode = :local
      @prompt = [[" (local mode)", :white]]
      show_update

    when :internet_mode
      @mode = :internet
      @bee ||= Beemind.spawn(:bee)
      @unsubmitted_work_pomodoros.times do
        @bee.tell(:submit_work_pomodoro)
      end
      @unsubmitted_work_pomodoros = 0
      @prompt = [[" (internet mode)", :white]]
      show_update

    when Array
      on_message(msg[0], msg[1])
    end
  end

  def set_status(msg)
    if @status != msg
      @status = msg
      @periods_in_state = 0
      @prompt = []
      show_update
    end
  end

  def show_update()
    update = if initialized?
      [["time tracker", :white]]
    else
      [["#{@status}: #{periods_to_minutes(@periods_in_state)} minutes#{pomodoro_proportion}#{accumulation}", state_color]]
    end + @prompt

    @outputs.each do |output|
      output.tell update
    end
  end

  def pomodoro_proportion
    if working?
      " (pom: #{100 * @work_pomodoro_periods / PERIODS_PER_POMODORO}%)"
    else
      ''
    end
  end

  def accumulation
    if @mode == :local
      " (accumulated: #{@unsubmitted_work_pomodoros})"
    else
      ''
    end
  end

  def on_tick
    @periods_in_state += 1

    if working?
      @work_pomodoro_periods += 1
    end

    if @work_pomodoro_periods >= PERIODS_PER_POMODORO
      finish_a_work_pomodoro
    end

    if counting_pomodoros? && @periods_in_state >= PERIODS_PER_POMODORO && @prompt.empty?
      @prompt = [["take a break", :white]]
      play_ding
    elsif break? && @periods_in_state >= PERIODS_PER_BREAK && @prompt.empty?
      @prompt = [["Break over", :white]]
      play_ding
    end
  end

  def finish_a_work_pomodoro
    @work_pomodoro_periods = 0
    @work_pomodoros_done_today += 1;
    if (@mode == :internet) && @bee
      @bee.tell(:submit_work_pomodoro)
    else
      @unsubmitted_work_pomodoros += 1
    end
  end

  def counting_pomodoros?
    working? || non_work?
  end

  def enough_work?
    @work_pomodoros_done_today >= MAX_DAILY_POMODOROS
  end

  def cls
    print "\e[H\e[2J"
  end

  def method_missing(method, *args, &block)
    if method[-1] == ??
      @status == method[0..-2].to_sym
    end
  end

  def state_color
    {
      initialized: :white,
      working: :light_green,
      break: :light_blue,
      non_work: :light_cyan
    }[@status] || :white
  end

  def play_ding(slow: false)
    speed = slow ? SLOW_DING_SPEED : DING_SPEED
    Process.spawn(
      'mplayer', DING_SOUND, '-speed', speed.to_s,
      out: '/dev/null',
      err: '/dev/null'
    )
  end
end
