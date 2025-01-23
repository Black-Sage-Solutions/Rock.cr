# Equivalent to Pane
class Rock::Bench
  @bounds : LibC::Winsize
  @face : Face

  def initialize(@bounds)
    @face = Face.new @bounds
  end

  delegate :c, to: @face

  def update_content(data)
    @face.write data
  end

  def render
    @face.render
  end
end
