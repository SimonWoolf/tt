require 'io/console'
require 'concurrent-edge'
require_relative 'controller'
require_relative 'cli_input_handler'
require_relative 'socket_input_handler'
require_relative 'terminal_output'
require_relative 'i3status_file_output'

options = {}
if ARGV.include?("-l") || ARGV.include?("--local")
  options[:mode] = :local
end

input_handler, options[:outputs] = if ARGV.include?("-s") || ARGV.include?("--socket")
  [SocketInputHandler.new, [I3statusFileOutput]]
else
  [CliInputHandler.new, [TerminalOutput]]
end

controller = Controller.spawn(:controller, options)

Signal.trap("WINCH") do
  Thread.new do
    controller.tell(:refresh)
  end
end

loop do
  case input_handler.get_input()
  when "\u0003"
    exit
  when ?q
    exit
  when ?w
    controller.tell(:working)
  when ?n
    controller.tell(:non_work)
  when ?b
    controller.tell(:break)
  when ?p
    controller.tell(:procrastinating)
  when ' '
    controller.tell(:refresh)
  when 'd'
    controller.tell(:deep_work)
  when 'o'
    controller.tell(:off)
  end
end
