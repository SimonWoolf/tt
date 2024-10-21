require 'active_support/core_ext/numeric/time'
require 'date'

def periods_to_minutes(periods)
  (periods * PERIOD_SECS) / 60
end

def minutes_to_periods(minutes)
  (minutes * 60) / PERIOD_SECS
end

def periods_to_hmstr(periods)
  hours, minutes = periods_to_minutes(periods).divmod(60)
  if hours == 0
    # pad with leading zero to make the length output monotonic - makes file output easier
    "#{minutes.to_s.rjust(2, '0')}m"
  else
    "#{hours}h#{minutes}m"
  end
end

PERIOD_SECS = 5
PERIODS_PER_POMODORO = minutes_to_periods(30)
PERIODS_PER_BREAK = minutes_to_periods(20)
WORK_PERIODS_TO_SAT = minutes_to_periods(4 * 60)
WORK_PERIODS_TO_OVERSAT = minutes_to_periods(8 * 60)
DING_SOUND = '/home/simon/dev/dotfiles/pomodoro-finish.wav'
WORK_DURATION_BY_DAY_FILEPATH = '/home/simon/work-log'
DING_SPEED = 3
SLOW_DING_SPEED = 2

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

    init_work_by_day_file

    @outputs = options[:outputs].map do |output|
      output.spawn(output.to_s)
    end
  end

  def init_work_by_day_file
    f = @work_by_day_file || (
      @work_by_day_file = File.open(WORK_DURATION_BY_DAY_FILEPATH, 'r+')
    )
    today = Date.today.to_s
    date_length = 10
    lines = f.readlines
    if lines.length > 0 && lines.last.start_with?(today)
      init_work_pom_periods(lines.last.slice(date_length + 1, 99))
      # seek to the beginning of the value of the last line
      @work_by_day_file_pos = f.pos - lines.last.length + date_length + 1
    else
      # no existing date
      f.write("\n#{today} ")
      @work_by_day_file_pos = f.pos
      f.write("\n")
    end
  end

  def init_work_pom_periods(hmstr)
    puts hmstr
    match_data = hmstr.match(/(?:(\d{1,2})h)?(\d{1,2})m/)
    puts match_data
    h, m = match_data.captures
    @work_pomodoro_periods = minutes_to_periods((h || '0').to_i * 60 + m.to_i)
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
      show_notification('ding')

    when :slow_ding
      sleep 5
      play_ding(slow: true)
      show_notification('slow ding')

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
      [["#{@status} #{periods_to_hmstr(@periods_in_state)}#{accumulation}", state_color]]
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
    "; work today: #{periods_to_hmstr(@work_pomodoro_periods)}" +
      if oversatisfied?
        " (🟥 oversatisfied)"
      elsif satisfied?
        " (: 🟠 satisfied)"
      else
        ""
      end +
      (@leisure_pomodoro_periods > 0 ? ", leisure today: #{periods_to_hmstr(@leisure_pomodoro_periods)}" : "") +
      (@task_pomodoro_periods > 0 ? ", task today: #{periods_to_hmstr(@task_pomodoro_periods)}" : "")
  end

  def oversatisfied?
    @work_pomodoro_periods > WORK_PERIODS_TO_OVERSAT
  end

  def satisfied?
    @work_pomodoro_periods > WORK_PERIODS_TO_SAT
  end

  def add_5_mins_of_work_periods
    periods_to_add = minutes_to_periods(5)
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
      init_work_by_day_file()
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

    if working? && (@work_pomodoro_periods === WORK_PERIODS_TO_SAT)
      show_notification('Satisfied obligation')
    end

    if working? && (@work_pomodoro_periods === WORK_PERIODS_TO_OVERSAT)
      show_notification('Oversatisfied obligation')
    end

    if working? && (@periods_in_state % PERIODS_PER_POMODORO == 0)
      play_ding(slow: false)
      show_notification('Pomodoro completed')
    end

    if break? && (@periods_in_state == PERIODS_PER_BREAK)
      play_ding(slow: true)
      show_notification('Break completed')
    end

    write_work_by_day_to_file
  end

  def write_work_by_day_to_file
    # overwrite any previous timestring (length of the hmstr is monotonically
    # increasing so don't worry about leaving anything at the end)
    f = @work_by_day_file
    f.seek(@work_by_day_file_pos)
    f.write(periods_to_hmstr(@work_pomodoro_periods))
    f.flush
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
    if working?
      if @periods_in_state >= PERIODS_PER_POMODORO
        :darkorange
      elsif satisfied?
        :orange
      else
        :yellow
      end
    elsif break?
      if @periods_in_state >= PERIODS_PER_BREAK
        :blue
      else
        :light_blue
      end
    else
      {
        initialized: :white,
        off: :white,
        non_work: :light_cyan,
        task: :green,
        leisure: :light_green,
      }[@status] || :white
    end
  end

  def play_ding(slow: false)
    speed = slow ? SLOW_DING_SPEED : DING_SPEED
    Process.detach(Process.spawn(
      'mplayer', DING_SOUND,
      '-speed', speed.to_s,
      '-volume', '60',
      in: '/dev/null',
      out: '/dev/null',
      err: '/dev/null'
    ))
  end

  def show_notification(text)
    Process.spawn('notify-send', 'Time tracker', text)
  end

  def yesterday?(time)
    # 4am cutoff
    (time - 4.hours).day != (Time.now - 4.hours).day
  end
end
