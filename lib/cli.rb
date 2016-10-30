require 'io/console'
require 'concurrent-edge'
require_relative 'controller'

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
