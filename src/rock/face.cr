# Buffer/content
class Rock::Face
  include Cursor

  @view_bounds : LibC::Winsize
  @doc : IO::Memory

  def initialize(@view_bounds, file = nil)
    @doc = IO::Memory.new @view_bounds.ws_row * @view_bounds.ws_col
  end

  private def buffer_current_line_pos
    count = 1
    pos = 0
    while pos < @doc.size
      break if count == row
      count += 1 if @doc.buffer[pos] == 13
      pos += 1
    end
    pos
  end

  private def number_of_lines
    count = 1
    pos = 0
    while pos < @doc.size
      count += 1 if @doc.buffer[pos] == 10
      pos += 1
    end
    count
  end

  private def end_of_current_line
    c = buffer_current_line_pos
    end_pos = c
    while end_pos < @doc.size
      break if @doc.buffer[end_pos] == 10
      end_pos += 1
    end

    end_pos - c
  end

  def col_max
    Math.min(end_of_current_line, @view_bounds.ws_col).to_u32
  end

  def row_max
    Math.min(number_of_lines, @view_bounds.ws_row).to_u32
  end

  def write(slice : Bytes)
    slice.each do |b|
      case b
      # TODO: remove writing '\r' to content, need to figure out the best way
      #       to setting the cursor when there is a '\n'
      when 13
        @doc.write_byte 10
        @doc.write_byte b
        next_line
        next
      else
        @doc.write_byte b
        fwd
      end
    end
  end

  def render
    @doc
  end
end
