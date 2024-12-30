module Rock
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
end
