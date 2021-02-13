require 'active_support/core_ext/numeric/time'

PERIOD_SECS = 5
PERIODS_PER_POMODORO = (25 * 60) / PERIOD_SECS
PERIODS_PER_BREAK = (5 * 60) / PERIOD_SECS
DING_SOUND = '/home/simon/dev/dotfiles/pomodoro-finish.wav'
DING_SPEED = 5
SLOW_DING_SPEED = 4

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
    @periods_in_state = 0
    @time_of_last_tick = Time.now
    @work_pomodoro_periods = 0
    @task_pomodoro_periods = 0
    @leisure_pomodoro_periods = 0
    @prompt = []

    @outputs = options[:outputs].map do |output|
      output.spawn(output.to_s)
    end
  end

  def on_message(msg, payload=nil)
    case msg
    when :tick
      unless disabled?
        on_tick
        show_update
      end

    when :disabled
      disable()

    when :working, :break, :procrastinating, :non_work, :task, :leisure, :off
      set_status(msg)

    when :refresh
      show_update

    when :info
      @prompt = [payload]
      show_update

    when :ding
      sleep 5
      play_ding()
      show_notification(false)

    when :slow_ding
      sleep 5
      play_ding(slow: true)
      show_notification(true)

    when :add
      add_5_mins_of_work_periods

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
    update = if initialized? || off?
      [["time tracker", :white]]
    else
      [["#{@status}: #{periods_to_minutes(@periods_in_state)}m#{accumulation}", state_color]]
    end + @prompt

    @outputs.each do |output|
      output.tell update
    end
  end

  def disable()
    @status = :disabled
    @outputs.each do |output|
      output.tell [["", :white]]
    end
  end

  def accumulation
    "; today: #{@work_pomodoro_periods / PERIODS_PER_POMODORO} wk"
      + (@task_pomodoro_periods > 0 ? ", #{@task_pomodoro_periods / PERIODS_PER_POMODORO} task" : "")
      + (@leisure_pomodoro_periods > 0 ? ", #{@leisure_pomodoro_periods / PERIODS_PER_POMODORO} leisure" : "")
  end

  def add_5_mins_of_work_periods
    periods_to_add = 5 * 60 / PERIOD_SECS
    periods_to_add.times do
      on_tick()
    end
  end

  def on_tick
    @periods_in_state += 1

    if yesterday?(@time_of_last_tick)
      @work_pomodoro_periods = 0
      @task_pomodoro_periods = 0
      @leisure_pomodoro_periods = 0
    end

    @time_of_last_tick = Time.now

    if working?
      @work_pomodoro_periods += 1
    end

    if task?
      @task_pomodoro_periods += 1
    end

    if leisure?
      @leisure_pomodoro_periods += 1
    end

    if time_exceeded?
      play_ding(slow: break?)
      show_notification(break?)
      @prompt = [["⏰", :white]] if @prompt.empty?
    end
  end

  def time_exceeded?
    (counting_pomodoros? && (@periods_in_state % PERIODS_PER_POMODORO == 0)) ||
      (break? && ((@periods_in_state - PERIODS_PER_BREAK) % PERIODS_PER_POMODORO == 0))
  end

  def counting_pomodoros?
    working? || non_work? || task? || leisure? || procrastinating?
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
      off: :white,
      working: :light_green,
      break: :light_blue,
      non_work: :light_cyan,
      task: :green,
      leisure: :yellow,
    }[@status] || :white
  end

  def play_ding(slow: false)
    speed = slow ? SLOW_DING_SPEED : DING_SPEED
    Process.detach(Process.spawn(
      'mplayer', DING_SOUND, '-speed', speed.to_s,
      in: '/dev/null',
      out: '/dev/null',
      err: '/dev/null'
    ))
  end

  def show_notification(break_end)
    Process.spawn('notify-send', 'Time tracker', break_end ? 'Break over' : 'End of pomodoro, take a break')
  end

  def yesterday?(time)
    # 4am cutoff
    (time - 4.hours).day != (Time.now - 4.hours).day
  end
end
