module Rock::Screen
  class_property! device : Terminal::Device

  def self.run
    device.draw do |d|
      d.write "\e[2J".to_slice

      (2..device.dim.ws_row - 3).each do |line|
        d.write "~".to_slice
        d.write "\e[#{line};0H".to_slice
      end

      d.write "\e[#{device.dim.ws_row - 2};#{0}H".to_slice
      d.write "\e[2K".to_slice
      d.write "Mode: TODO".to_slice
      d.write "\e[4C".to_slice
      d.write "Cursor: TOD".to_slice
      d.write "\e[4C".to_slice
      d.write "Event: #{nil}".to_slice
      d.write "\e[0E".to_slice
    end

    spawn name: "UI" do
      loop do
        event = Quarry::Radio.receive_first(
          Terminal::Keys.radio,
          Terminal::Mouse.radio,
        )

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
          d.write "Mode: TODO".to_slice
          d.write "\e[4C".to_slice
          d.write "Cursor: TOD".to_slice
          d.write "\e[4C".to_slice
          d.write "Event: #{event}".to_slice
          d.write "\e[0E".to_slice
        end
        # sleep 16.milliseconds
      end
    end
  end
end
