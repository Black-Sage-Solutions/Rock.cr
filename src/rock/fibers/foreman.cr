# Manages the input from the user.
#
# TODO:
# - how to have key mappings like nvim in a compiled editor?
#   Possible solutions?:
#     * Remapping just the keys wouldn't be too difficult
#     ? how to allow the user to have callbacks on any key maps
#         - embed script language
#         - how to have crystal interpreter in own program?
module Rock::Foreman
  class_property! device : Terminal::Device

  def self.run
    spawn name: "Foreman" do
      loop do
        begin
          buf = device.input.peek
          break unless buf.size

          # There can be multiple input sequences within a read from STDIN
          case buf.first
          when 3 # ctl_c
            device.close
            exit(0)
          when 27 # \e
            device.mouse.parse(buf).each do |ev|
              Terminal::Mouse.radio.send ev
            end
          else
            Terminal::Keys.radio.send device.keys.parse(buf)
          end

          # Must clear the device's IO for next iteration's use of `.peek`
          # At this time, is meant for STDIN on the terminal, but should try to
          # follow Crystal's mechanics of IO::Buffering for future IO devices
          device.input.rewind
        rescue
        ensure
        end
      end
    end
  end
end
