require 'io/console'
require 'concurrent-edge'
require_relative 'controller'

# Set title of the terminal
system("printf \"\033]0;tt\007\"")

options = {}
if ARGV.include?("-l") || ARGV.include?("--local")
  options[:mode] = :local
end

controller = Controller.spawn(:controller, options)

Signal.trap("WINCH") do
  Thread.new do
    controller.tell(:refresh)
  end
end

loop do
  case STDIN.getch
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
  when 'l'
    controller.tell(:local_mode)
  when 'i'
    controller.tell(:internet_mode)
  end
end
