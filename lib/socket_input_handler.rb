require 'socket'
SOCKET_PATH = "/tmp/tt.sock"

class SocketInputHandler
  def initialize()
    if File.exists?(SOCKET_PATH) && File.socket?(SOCKET_PATH)
      File.unlink(SOCKET_PATH)
    end

    @server = UNIXServer.open(SOCKET_PATH)
  end

  def get_input()
    sock = @server.accept()
    command = sock.readline.chomp()
    sock.close()
    command
  end
end
