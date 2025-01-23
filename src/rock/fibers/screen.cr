module Rock::Screen
  class_property! device : Terminal::Device

  class_property act_bench = 0
  class_property mode = Mode::Normal

  @@benches = Array(Bench).new

  # Note: Need reference within the Proc for modules or objects because the
  #       inline block doesnt retain the same scope when running in the fiber
  KeyMap.add(Mode.all, "\e") { Screen.mode = Mode::Normal }
  KeyMap.add(Mode::Normal, "i") { Screen.mode = Mode::Insert }
  KeyMap.add(Mode::Normal, "R") { self.mode = Mode::Replace }
  visuals = Mode.include(:normal, :visual, :visualblock, :visualline)
  KeyMap.add(visuals, "v") { self.mode = Mode::Visual }
  KeyMap.add(visuals, "\u0016") { self.mode = Mode::VisualBlock }
  KeyMap.add(visuals, "V") { self.mode = Mode::VisualLine }

  # TODO: is there a better spot for this kind of initialization?
  # TODO: have keymaps take an int for the sequence to save memory (i think
  #       it would help, but maybe they get garbage collected at some point?)
  (32_u8..255_u8).each do |b|
    bytes = Bytes[b]
    KeyMap.add Mode::Insert, bytes, &-> { update_content bytes }
  end
  # TODO: (byte 9 is Tab) how to adjust the size of the tab in the terminal?
  KeyMap.add Mode::Insert, Bytes[9], &-> { update_content Bytes[9] }
  KeyMap.add Mode::Insert, Bytes[10], &-> { update_content Bytes[10] }
  KeyMap.add Mode::Insert, Bytes[13], &-> { update_content Bytes[13] }

  cursor_modes = Mode.exclude(:insert, :replace, :command)
  KeyMap.add cursor_modes, "h", &-> { active_bench.c.back_x }
  KeyMap.add cursor_modes, "j", &-> { active_bench.c.down_y }
  KeyMap.add cursor_modes, "k", &-> { active_bench.c.up_y }
  KeyMap.add cursor_modes, "l", &-> { active_bench.c.fwd_x }
  KeyMap.add cursor_modes, "\u0010", &-> { active_bench.c.prev_line } # Ctrl-p
  KeyMap.add cursor_modes, "\u000E", &-> { active_bench.c.next_line } # Ctrl-n

  def self.active_bench
    @@benches[act_bench]
  end

  def self.update_content(data)
    active_bench.update_content data
  end

  def self.run
    # TODO: update cursor's bounds on terminal resize & bench changes
    @@benches << Bench.new Screen.device.dim

    device.draw &.write("\e[2J".to_slice)

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

        Screen.device.draw do |o|
          bench = active_bench

          o.write bench.render.to_slice

          o.write "\e[#{Screen.device.dim.ws_row - 2};#{0}H".to_slice
          o.write "\e[2K".to_slice
          o.write "Mode: #{Screen.mode}".to_slice
          o.write "\e[4C".to_slice
          o.write "Cursor: #{bench.c}".to_slice
          o.write "\e[4C".to_slice
          o.write "Event: #{event}".to_slice
          o.write "\e[0E".to_slice

          o.write "\e[#{bench.c.y};#{bench.c.x}H".to_slice
        end

        # sleep 16.milliseconds
      end
    end
  end
end
