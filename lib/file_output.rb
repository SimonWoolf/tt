class FileOutput < Concurrent::Actor::Context
  PATH = "/tmp/tt_status"

  def on_message(msg)
    f = File.open(PATH, "w")
    f.write(msg)
    f.close()
  end
end
