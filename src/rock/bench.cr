# Equivalent to Pane
class Rock::Bench
  property view_bounds : LibC::Winsize

  @face : Face

  def initialize(@view_bounds)
    @face = Face.new @view_bounds
  end

  delegate :bwd, :fwd, :down, :up, :next_line, :prev_line, :pos, to: @face

  def update_content(data)
    @face.write data
  end

  def render
    @face.render
  end
end
