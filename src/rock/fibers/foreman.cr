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

  class_getter radio : Channel(EventKind) = Channel(EventKind).new

  enum EventKind
    Quit
  end

  KeyMap.add "\u0003" { radio.send EventKind::Quit }

  def self.run
    # TODO: reference fiber for finer control?
    spawn name: "Foreman" do
      loop do
        buf = device.input.peek
        break unless buf.size

        # So far each read from the input buffer has yielded either key or
        # mouse sequences.
        # It's unclear if there will be a mix of sequences, including in
        # situtations when this fiber is blocked from reading the input buffer
        # for some amount of time. Due to the difficulty of gathering the
        # real-time data when I was experiencing this behaviour, I'm not able
        # to confirm yet if this happens or not.
        case buf.first
        when 27 # \e, start of CSI sequence, for right now assuming mouse events
          # TODO: filter out mouse movements when there are no button presses,
          #       I can't think of any reason for needing to process tracking
          device.mouse.parse(buf).each do |ev|
            # TODO: need to store mouse state for button presses
            Terminal::Mouse.radio.send ev unless ev.button == 3
          end
        else
          device.keys.parse(buf).each do |ev|
            Terminal::Keys.radio.send ev
          end
        end

        # Must clear the device's IO for next iteration's use of `.peek`
        # At this time, is meant for STDIN on the terminal, but should try to
        # follow Crystal's mechanics of IO::Buffering for future IO devices
        device.input.rewind
      end
    end
  end
end
