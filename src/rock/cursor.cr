class Rock::Cursor
  property x : UInt32, y : UInt32

  def initialize(@x, @y, @winsize : LibC::Winsize)
    KeyMap.add "h", &->back_x
    KeyMap.add "j", &->down_y
    KeyMap.add "k", &->up_y
    KeyMap.add "l", &->fwd_x
    KeyMap.add "\u0010", &->prev_line # Ctrl-p
    KeyMap.add "\u000E", &->next_line # Ctrl-n
  end

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

  def to_s(io : IO) : Nil
    io << "Cursor("
    io << "@x=" << x << ", @y=" << y
    io << ")"
  end
end
