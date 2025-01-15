module Rock::Terminal
  class Mouse
    class_property radio : Quarry::Radio(Mouse::Event) = Quarry::Radio(Mouse::Event).new

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
    # Setting as a class instance for singleton approach
    class_property radio : Quarry::Radio(Keys::Event) = Quarry::Radio(Keys::Event).new

    # TODO: allocate bytes with the size of the largest key map
    # Currently intent to have only 1 instance of this object running in the
    # Foreman fiber, this handling is not multi-thread safe
    @history = Bytes.new 0

    def initialize
    end

    def clear
      @history = Bytes.new 0
    end

    def parse(stream : Bytes)
      @history += stream
      find_keymaps
    end

    private def find_keymaps : Event
      # TODO: find most optimal data structure for searching based on key path
      # options could be a vector, b-tree
      keys_and_actions = {
        "h"  => -> { },
        "j"  => -> { },
        "k"  => -> { },
        "l"  => -> { },
        "dd" => -> { },
      }

      # TODO: mode check
      found_actions = keys_and_actions.select do |k, v|
        k.to_slice == @history ||
          k.to_unsafe.memcmp(@history.to_unsafe, @history.bytesize) == 0
      end

      begin
        case found_actions.size
        when 1
          Keys::Event.new @history, :yes, found_actions.first[1]
        when .> 1
          Keys::Event.new @history, :partial
        else
          Keys::Event.new @history, :no
        end
      ensure
        clear unless found_actions.size > 1
      end
    end
  end

  struct Keys::Event
    def initialize(@keys : Bytes, @found : Symbol, @action : Proc(Nil)? = nil)
    end
  end

  class Device
    @initial_term_mode : LibC::Termios

    getter dim : LibC::Winsize
    getter! keys : Terminal::Keys
    getter! mouse : Terminal::Mouse

    @input = STDIN
    @output = STDOUT

    def initialize
      if !input.tty? || !output.tty?
        raise "Not running via terminal emulator."
      end

      if LibC.tcgetattr(input.fd, out term_mode) != 0
        raise IO::Error.from_errno("tcgetattr")
      end

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

    def clear
      output.write "\e[2J".to_slice
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
      yield output
    end
  end
end
