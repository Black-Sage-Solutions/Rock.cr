module Rock::Screen
  class_property! device : Terminal::Device

  def self.run
    spawn name: "UI" do
      loop do
        event = Quarry::Radio.receive_first(
          Terminal::Keys.radio,
          Terminal::Mouse.radio,
        )

        device.draw do |d|
          d.write "\e[2J".to_slice
          d.write "\e[0;0H".to_slice

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
          d.write "Event: #{event}".to_slice
          d.write "\e[0E".to_slice
        end
        sleep 16.milliseconds
      end
    end
  end
end
