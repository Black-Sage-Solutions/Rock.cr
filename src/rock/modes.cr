# `Rock`'s editor state controller. Each `Mode`'s value corresponds to the key
# press byte.
#
# eg.
# ```
# mode = Mode::Normal
# mode = Mode::Visual
# ```
enum Rock::Mode : UInt8
  VisualBlock =  22
  Command     =  58
  Replace     =  82
  VisualLine  =  86
  Insert      = 105
  Normal      = 110
  Visual      = 118

  # Helper method for joining the main key press sequence to the mode enum
  # constant's byte value.
  #
  # eg.
  # ```
  # m = Mode::Insert
  # sequence = m.to_keyseq "\u0006" # <Ctrl-f>
  # pp! sequence # sequence # => Bytes[105, 6]
  # ```
  def to_keyseq(value : Bytes | String) : Bytes
    buf_size = sizeof(UInt8) + value.bytesize
    buf = Pointer(UInt8).malloc(buf_size)
    ptr = buf
    ptr[0] = self.value
    ptr = buf + 1
    ptr.copy_from(value.to_slice.to_unsafe, value.bytesize)
    buf.to_slice buf_size
  end

  # Additional comparison method on `Mode` constants for varying types.
  def ==(value : Int | String | Symbol)
    self == case value
    in Int
      Mode.from_value? value
    in String
      Mode.parse? value
    in Symbol
      Mode.parse? value.to_s
    end
  end

  # Gets all the `Mode` constant's values.
  def self.all
    values
  end

  # Get a list of `Mode` constants. To reduce excessive typing, equivalent
  # values of other typing can be used.
  #
  # Note: generally with `Enum`s provided as a type in a method's argument(s)
  # the Crystal compiler will try to autocast the incoming parameter if the
  # value is a `Symbol`. However, while this method works in the Crystal
  # playground, when executed for real use, it fails due to expecting a type
  # from the `Union`. In order to use a `Symbol` equivalent as a parameter,
  # the method needed to explicitly include the `Symbol` type and handle the
  # logic for value comparison.
  #
  # eg.
  # ```
  # pp! Mode.include(22, "Replace", :normal, Mode::Visual)
  # # => [Mode::VisualBlock, Mode::Replace, Mode::Normal, Mode::Visual]
  # ```
  def self.include(*inc : Int | String | Symbol | self)
    selected = Array(self).new
    each do |mode|
      selected << mode if inc.any? { |i| mode == i }
    end
    selected
  end

  # Get a list of `Mode` constants without the specified values. To reduce
  # excessive typing, equivalent values of other typing can be used.
  #
  # Note: generally with `Enum`s provided as a type in a method's argument(s)
  # the Crystal compiler will try to autocast the incoming parameter if the
  # value is a `Symbol`. However, while this method works in the Crystal
  # playground, when executed for real use, it fails due to expecting a type
  # from the `Union`. In order to use a `Symbol` equivalent as a parameter,
  # the method needed to explicitly include the `Symbol` type and handle the
  # logic for value comparison.
  #
  # eg.
  # ```
  # Mode.exclude(22, "Replace", :normal, Mode::Visual)
  # # => [Mode::Command, Mode::VisualLine, Mode::Insert]
  # ```
  def self.exclude(*ex : Int | String | Symbol | self)
    selected = Array(self).new
    each do |mode|
      selected << mode unless ex.any? { |e| mode == e }
    end
    selected
  end
end
