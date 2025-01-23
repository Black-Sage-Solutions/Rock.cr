# Buffer/content
class Rock::Face
  @bounds : LibC::Winsize
  @c : Cursor
  @int_buf = IO::Memory.new 4096

  def initialize(@bounds, file = nil)
    @c = Cursor.new 1, 1, @bounds
  end

  def c
    @c
  end

  def write(slice : Bytes)
    slice.each do |b|
      case b
      when 13
        @int_buf.write_byte 10
        c.next_line
      end
      @int_buf.write_byte b
      c.fwd_x unless b == 13
    end
  end

  def render
    @int_buf
  end
end
