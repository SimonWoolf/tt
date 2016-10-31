require 'io/console'
require 'concurrent-edge'
require_relative 'controller'

# Set title of the terminal
system("printf \"\033]0;tt\007\"")

controller = Controller.spawn(:controller)

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
  when ?p
    controller.tell(:procrastinating)
  end
end
