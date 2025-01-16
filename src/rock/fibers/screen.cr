module Rock::Screen
  class_property! device : Terminal::Device

  def self.run
    # TODO: have cursor and mode per pane
    c = Cursor.new 1, 1, device.dim
    m = Mode::Normal

    device.draw do |d|
      d.write "\e[2J".to_slice

      (2..device.dim.ws_row - 3).each do |line|
        d.write "~".to_slice
        d.write "\e[#{line};0H".to_slice
      end

      d.write "\e[#{device.dim.ws_row - 2};#{0}H".to_slice
      d.write "\e[2K".to_slice
      d.write "Mode: #{m}".to_slice
      d.write "\e[4C".to_slice
      d.write "Cursor: #{c}".to_slice
      d.write "\e[4C".to_slice
      d.write "Event: #{nil}".to_slice
      d.write "\e[0E".to_slice
    end

    spawn name: "UI" do
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
          d.write "Mode: #{m}".to_slice
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
