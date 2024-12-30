require "./rock/libc"
require "termios"

def get_term_dim() : LibC::Winsize
  ws = LibC::Winsize.new
  ret = LibC.ioctl(STDOUT.fd, LibC::TIOCGWINSZ, pointerof(ws))
  if ret < 0
    raise "Failed to get terminal dimentions"
  end
  ws
end

if !STDIN.tty? || !STDOUT.tty?
  puts "Error: Not running via terminal emulator."
  exit 1
end

# TODO: i forgot why this is needed?
if LibC.tcgetattr(STDIN.fd, out mode) != 0
  raise IO::Error.from_errno("tcgetattr")
end

before = mode
mode.c_lflag &= ~Termios::LocalMode.flags(ECHO, ICANON).value
LibC.tcsetattr STDIN.fd, Termios::LineControl::TCSANOW, pointerof(mode)

winsize = get_term_dim

Signal::WINCH.trap do
  winsize = get_term_dim
end

STDOUT.write "\e[2J".to_slice
STDOUT.write "\e[H".to_slice

(0...winsize.ws_row).each do |line|
  STDOUT.write "~\n".to_slice
end

quit = false

struct Buffer
end

struct Cursor
  property x : UInt32, y : UInt32

  def initialize(@x, @y, @winsize : LibC::Winsize); end

  def next_line
    @x = 1
    @y += 1
  end

  def prev_line
    # TODO figure out how to position at the end of the previous line
    # might depend on how i will manage the text
    @y -= 1 if @y > 0
  end

  def fwd_x
    @x += 1 if @x < @winsize.ws_col
  end

  def back_x
    @x -= 1 if @x > 1
  end

  def down_y
    @y += 1 if @y < @winsize.ws_row
  end

  def up_y
    @y -= 1 if @y > 1
  end

  def move
    STDOUT.write "\e[#{@y};#{@x}H".to_slice
  end

  def to_s(io : IO) : Nil
  end
end

# TODO: multiple cursors
# there's a need for at least 2, 1 for normal/insert, 1 for command
c = Cursor.new 1, 1, winsize

enum Mode
  Command
  Normal
  Insert
  Visual
  VisualBlock
  VisualLine
end

m = Mode::Normal

STDOUT.write "\e[#{winsize.ws_row - 8};#{0}H".to_slice
STDOUT.write "\e[2K".to_slice
STDOUT.write "Mode: #{m}".to_slice
STDOUT.write "\e[4C".to_slice
STDOUT.write "Cursor: #{c}".to_slice

while !quit && STDIN.not_nil!
  STDIN.flush
  c.move
  user_input = STDIN.read_char
  quit = user_input.to_s == "q"
  case m
  when Mode::Normal
    # TODO: move key references to a file
    c.fwd_x if user_input == 'l'
    c.down_y if user_input == 'j'
    c.back_x if user_input == 'h'
    c.up_y if user_input == 'k'
    m = Mode::Insert if user_input == 'i'
    if user_input == ':'
      m = Mode::Command
      c.x = 2
      c.y = winsize.ws_row - 3
    end
  when Mode::Command
    if user_input == '\n'
      m = Mode::Normal
    elsif user_input.not_nil!.ord == 127
      c.back_x
      c.move
      user_input = ' '
      if c.x == 1
        c.prev_line
        c.move
      end
    elsif user_input == '\e'
    else
      c.fwd_x
    end
    m = Mode::Normal if user_input == '\e'
    STDOUT.write user_input.to_s.to_slice unless user_input == '\e'
    STDOUT.write "\e[#{winsize.ws_row - 3};#{0}H".to_slice
    STDOUT.write ":".to_slice
  when Mode::Insert
    if user_input == '\n'
      c.next_line
    elsif user_input.not_nil!.ord == 127
      c.back_x
      c.move
      user_input = ' '
      if c.x == 0
        c.prev_line
        c.move
      end
    elsif user_input == '\e'
    else
      c.fwd_x
    end
    m = Mode::Normal if user_input == '\e'
    STDOUT.write user_input.to_s.to_slice unless user_input == '\e'
  end

  # Extra info
  STDOUT.write "\e[#{winsize.ws_row - 8};#{0}H".to_slice
  STDOUT.write "\e[2K".to_slice
  STDOUT.write "Mode: #{m}".to_slice
  STDOUT.write "\e[4C".to_slice
  STDOUT.write "Input: #{user_input.not_nil!.bytes}".to_slice
  STDOUT.write "\e[4C".to_slice
  STDOUT.write "Cursor: #{c}".to_slice
end

STDOUT.write "\e[0J".to_slice
STDOUT.write "\n".to_slice
LibC.tcsetattr STDIN.fd, Termios::LineControl::TCSANOW, pointerof(before)
puts "so long gay bowsie!"

0
