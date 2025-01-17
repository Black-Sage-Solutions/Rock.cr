require "./fibers/*"

module Rock
  def self.main
    device = Terminal::Device.new
    begin
      Screen.device = device
      Screen.run
      Foreman.device = device
      Foreman.run
      loop do
        # I'm not sure what's best here, but this loop is to keep the program
        # running for the other other spawned fibers.
        # At some point this point could be used to manage main process events
        # for example quitting the editor and running the necessary cleanup
        # steps that all the modules may need to do
        #
        case Foreman.radio.receive
        in Foreman::Event::Quit
          break
        end
      end
    ensure
      device.close
      STDOUT.write "\e[0E".to_slice
      puts "so long gay bowsie!"
      0 # FIXME: keep track of an exit code status
    end
  end
end
