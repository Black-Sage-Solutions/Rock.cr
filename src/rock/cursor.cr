require "math"

module Rock::Cursor
  property col : UInt32 = 1_u32
  property row : UInt32 = 1_u32

  abstract def col_max
  abstract def row_max

  def pos
    {col, row}
  end

  def next_line
    @row = Math.min(row + 1, row_max)
    @col = Math.min(col, col_max)
  end

  def prev_line
    @row -= 1 unless row <= 1
    @col = Math.min(col, col_max)
  end

  def fwd
    @col += 1 unless col >= col_max
  end

  def bwd
    @col -= 1 unless col <= 1
  end

  def down
    next_line
  end

  def up
    prev_line
  end
end
