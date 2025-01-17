module Rock::Terminal
  class Mouse
    class_property radio : Channel(Mouse::Event) = Channel(Mouse::Event).new

    getter prefix : Bytes = Bytes[27, 91, 60] # '\e[<' CSI < prefix for SGR

    def initialize(@device : IO::FileDescriptor, @vt_mode = Mode::SGR)
      # https://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h2-Mouse-Tracking
      # Turn on mouse events for SGR ext mode and any mouse events
      @device.write "\e[?#{mode_code};1003h".to_slice
    end

    # TODO: at some point before exitting, need to disable the mouse modes
    #       on STDIN, as it can be a side-effect for other applications that
    #       rely on certain mouse mode exts
    def disable
      @device.write "\e[?#{mode_code};1003l".to_slice
    end

    def mode_code
      Mode[@vt_mode].value
    end

    def parse(stream : Bytes) : Array(Event)
      events = Array(Event).new
      split = 0
      stream.each_with_index do |b, i|
        case b
        when 'M', 'm'
          events << Event.new stream[split..i]
          split = i + 1
        end
      end
      events
    end
  end

  # Currently Event is only working for SGR mouse events
  # https://stackoverflow.com/a/77410870
  # each byte besides the delimiting chars, are an ascii digit,
  # eg. Byte[49] == "one" or '1', Byte[49,48] == "one""zero" or '10'
  struct Mouse::Event
    def initialize(@seq : Bytes)
    end

    def button
      @seq[3] - 48
    end

    def mod
      @seq[4] - 48 unless @seq[4] === ';'
    end

    def col
      start = @seq.index!(';'.ord, 3) + 1
      fin = @seq.rindex!(';'.ord)
      raise "Malformed byte sequence for Cx" if start >= fin
      @seq[start...fin].reduce 0_u16 { |a, c| a * 10 + (c - 48) }
    end

    def row
      start = @seq.rindex(';'.ord)
      raise "Malformed byte sequence for Cy" unless start
      @seq[start + 1...-1].reduce 0_u16 { |a, c| a * 10 + (c - 48) }
    end

    def release?
      @seq[-1] === 'm'
    end
  end

  enum Mouse::Mode
    SGR = 1006
  end

  class Keys
    class_property radio : Channel(Keys::Event) = Channel(Keys::Event).new

    # TODO: set alloc size relative to KeyMap's largest possible key, but the
    #       question becomes when should that happen?
    #       Find out when Rock would finish adding the keymaps.
    @history = Bytes.new 10
    @append : Pointer::Appender(UInt8)

    def initialize
       @append = @history.to_unsafe.appender
    end

    def clear
      @history.fill 0
      @append = @history.to_unsafe.appender
    end

    # FIXME?: at times there maybe multiple key sequences when reading from
    #         input, usually due to the user pressing 2 keys at or very close
    #         to the same time.
    #         Similar to mouse sequences, may want to process key sequences
    #         individually instead.
    def parse(stream : Bytes) : Slice(Event)
      stream.map do |b|
        @append << b
        current = @append.to_slice.dup
        actions = KeyMap.find_actions current
        case actions.size
        when 0
          clear
          Keys::Event.new current, :miss
        when 1
          clear
          Keys::Event.new current, :yes, actions.first[1]
        else
          # idk what do in code for having a running timer when the user
          # hasn't done any addition input when there is an exact match within
          # the partial list
          Keys::Event.new current, :partial
        end
      end
    end
  end

  struct Keys::Event
    getter keys, hits
    getter? action

    def initialize(@keys : Bytes, @hits : Symbol, @action : KeyMap::Action? = nil)
    end
  end

  class Device
    @initial_term_mode : LibC::Termios

    getter dim : LibC::Winsize
    getter! keys : Terminal::Keys
    getter! mouse : Terminal::Mouse

    # There can be multiple input sequences when reading from STDIN,
    # eg. 2 keys or 4 mouse sequences
    #
    # Additionally, when reading from within a separate fiber, the STDIN buffer
    # can accumulate when the containing fiber is waiting for other fibers to
    # finish.
    #
    # Important to note, at this time it's unclear under expected conditions,
    # when reading/peeking STDIN for mouse or key sequences, if the buffer will
    # solely have mouse sequences or key button sequences.
    #
    # As well, with the above situation when the STDIN buffer is accumulating
    # due to the processing fiber being blocked, if there are a mix of key and
    # mouse sequences.
    @input = STDIN
    @output = STDOUT

    def initialize
      if !input.tty? || !output.tty?
        raise "Not running via terminal emulator."
      end

      if LibC.tcgetattr(input.fd, out term_mode) != 0
        raise IO::Error.from_errno("tcgetattr")
      end

      # TODO: use xterm's private modes, possible for achieving similar
      #       behaviour nvim does on startup and exit
      #       https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797?permalink_comment_id=3878578#common-private-modes

      @initial_term_mode = term_mode

      # Disabling input device's (terminal) communication controls.
      # There is more information on `man termios`, the following is a brief
      # summary of why we are setting certain flags on or off
      #
      # Control Flags
      # CS8: sets the character size to 8 bits per byte
      #
      # Input Flags
      # BRKINT: disabled to handle a break condition `tcsendbreak()` as SIGINT
      #
      # ICRNL: disabled to set ctrl-m and enter key to real value 13 instead
      #        of 13, idk the reason for the translating
      #
      # INPCK: disabled of parity checking, doesn't apply to modern terminal
      #       emulators
      #
      # ISTRIP: disabled to not set the 8th bit of each input byte to 0
      #
      # IXON: disabled the software flow control for pause and resume
      #       transmission with ctrl-s and ctrl-q respectively
      #
      # Output Flags
      # OPOST: disabled the terminal output processing for streamlining certain
      #        character sequences, eg. '\r\n' to '\n'
      #
      # Line Control Flags
      # ECHO: disabled the terminal to echoing input characters when the user
      #       types
      #
      # ICANON: disabled the terminal to process input line-by-line and instead
      #         process user input byte-by-byte
      #
      # IEXTEN: disabled ctrl-v for the terminal to not send the next
      #         character literially. For macos, disabled ctrl-o for discarding
      #         the control character
      #
      # ISIG: disabled the terminal emulator to handling signal key presses
      #
      # Control Character
      # VMIN: sets the minimum number of bytes for read() will return, 1 sets
      #       the control to return when at least 1 byte is ready. We don't
      #       need to set as 0 because Crystal uses an event loop for
      #       handling when reading from STDIN for user input from the
      #       terminal application.
      #
      # VTIME: set the maximum amount of time to wait for before read()
      #        returns, value is the 10th number of a second
      #        eg. value of 1 means 0.1 second
      #            value of 0 mean send data right away
      #
      term_mode.c_cflag |= (LibC::CS8)
      term_mode.c_iflag &= ~(LibC::BRKINT | LibC::ICRNL | LibC::INPCK | LibC::ISTRIP | LibC::IXON)
      term_mode.c_oflag &= ~(LibC::OPOST)
      term_mode.c_lflag &= ~(LibC::ECHO | LibC::ICANON | LibC::IEXTEN | LibC::ISIG)
      term_mode.c_cc[LibC::VMIN] = 1
      term_mode.c_cc[LibC::VTIME] = 0
      LibC.tcsetattr input.fd, LibC::TCSANOW, pointerof(term_mode)

      input.blocking = false

      @dim = LibC::Winsize.new
      @keys = Terminal::Keys.new
      @mouse = Terminal::Mouse.new input

      get_dimentions

      # Trying again with putting the handler here again and seeing if it will
      # avoid invalid addr issues by being in a class instead
      Signal::WINCH.trap do
        self.get_dimentions
      end
    end

    def input
      @input.not_nil!
    end

    def output
      @output.not_nil!
    end

    # Clear the output display
    #
    # Note: there are 2 ESC Erase sequences that clear the terminal that have
    #       different mechanics.
    #       '\e[0J' or '\e[J' will erase the display
    #       '\e[2J' will erase the screen
    #       the difference is the 2J sequence will page the content, similar
    #       to how CTRL-l in the shell will clear the screen but scrolling up
    #       will show the previous content. 0J or J will delete the output
    #       permanently.
    #
    #       So for the main drawing procedure of the editor, 0J or J sequences
    #       should be used.
    def clear
      output.write "\e[0J".to_slice
      output.write "\e[0;0H".to_slice
    end

    # TODO: find best way for running this code when the program is exitting
    #       at any point
    def close
      output.write "\e[0J".to_slice
      output.write "Terminal::Device closing...".to_slice
      mouse.disable
      LibC.tcsetattr input.fd, LibC::TCSANOW, pointerof(@initial_term_mode)
    end

    def get_dimentions
      ret = LibC.ioctl(output.fd, LibC::TIOCGWINSZ, pointerof(@dim))
      if ret != 0
        raise "Failed to get terminal dimentions"
      end
    end

    def draw(&block : IO::FileDescriptor -> Nil)
      clear
      yield output
    end
  end
end
