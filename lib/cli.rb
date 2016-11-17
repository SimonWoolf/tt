require 'io/console'
require 'concurrent-edge'
require_relative 'controller'

# Set title of the terminal
system("printf \"\033]0;tt\007\"")

controller = Controller.spawn(:controller)

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
  end
end
