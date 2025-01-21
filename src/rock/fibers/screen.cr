module Rock::Screen
  class_property! device : Terminal::Device

  class_property mode = Mode::Normal

  # Note: Need reference within the Proc for modules or objects because the
  #       inline block doesnt retain the same scope when running in the fiber
  KeyMap.add(Mode.all, "\e") { Screen.mode = Mode::Normal }
  KeyMap.add(Mode::Normal, "i") { Screen.mode = Mode::Insert }
  KeyMap.add(Mode::Normal, "R") { self.mode = Mode::Replace }
  visuals = Mode.include(:normal, :visual, :visualblock, :visualline)
  KeyMap.add(visuals, "v") { self.mode = Mode::Visual }
  KeyMap.add(visuals, "\u0016") { self.mode = Mode::VisualBlock }
  KeyMap.add(visuals, "V") { self.mode = Mode::VisualLine }

  def self.run
    c = Cursor.new 1, 1, device.dim

    device.draw do |d|
      d.write "\e[2J".to_slice

      (2..device.dim.ws_row - 3).each do |line|
        d.write "~".to_slice
        d.write "\e[#{line};0H".to_slice
      end

      d.write "\e[#{device.dim.ws_row - 2};#{0}H".to_slice
      d.write "\e[2K".to_slice
      d.write "Mode: #{mode}".to_slice
      d.write "\e[4C".to_slice
      d.write "Cursor: #{c}".to_slice
      d.write "\e[4C".to_slice
      d.write "Event: #{nil}".to_slice
      d.write "\e[0E".to_slice
    end

    spawn name: "Screen" do
      loop do
        case event = Channel.receive_first(
          Terminal::Keys.radio,
          Terminal::Mouse.radio,
        )
        in Terminal::Keys::Event
          # TODO: evaluate spawning a fiber for input events
          event.action?.not_nil!.call if event.hits == :yes
        in Terminal::Mouse::Event
        end

        # Looks like this is what I was looking for on handling user input
        # without blocking the renderer
        # but it causes a huge backup of the input buffer in the Foreman fiber
        # when the user is rapidly using the mouse
        # event = select
        # when keys = Terminal::Keys.radio.receive?
        #  keys
        # when mouse = Terminal::Mouse.radio.receive?
        #  mouse
        # else
        #  nil
        # end

        device.draw do |d|
          (2..device.dim.ws_row - 3).each do |line|
            d.write "~".to_slice
            d.write "\e[0E".to_slice
          end

          d.write "\e[#{device.dim.ws_row - 2};#{0}H".to_slice
          d.write "\e[2K".to_slice
          d.write "Mode: #{mode}".to_slice
          d.write "\e[4C".to_slice
          d.write "Cursor: #{c}".to_slice
          d.write "\e[4C".to_slice
          d.write "Event: #{event}".to_slice
          d.write "\e[0E".to_slice
        end
        # sleep 16.milliseconds
      end
    end
  end
end
