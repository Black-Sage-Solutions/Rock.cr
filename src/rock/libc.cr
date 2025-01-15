# The Crystal LibC module doesn't include certain definitions, for example
# getting the window size of the terminal emulator.
# 
# We will include the necessary references in the std LibC module.
lib LibC
  struct Winsize
    ws_row : UInt16
    ws_col : UInt16
    ws_xpixel : UInt16
    ws_ypixel : UInt16
  end

  {% begin %}
    # TIOCGWINSZ is a magic number passed to ioctl that requests the current
    # terminal window size. It is hardware platform (CPU arch) dependent
    # (see https://stackoverflow.com/a/4286840).
    {% if flag?(:darwin) || flag?(:bsd) %}
      # BSD uses the `_IOR` macro to determine the value, see
      # `c/get_libc_const.c`
      TIOCGWINSZ = 0x40087468
      # VTIME for termios cc mode setting is missing
      VTIME = 17
    {% elsif flag?(:unix) %}
      # This is the generic const set in `include/uapi/asm-generic/ioctls.h`
      TIOCGWINSZ = 0x5413
    {% end %}
  {% end %}

  # Control Device - Declaration for manipulating the underlying device
  # parameters of special files.
  #
  # Intended for use on Linux and MacOS, this function may differ between
  # different platforms.
  # 
  # See `man ioctl` for more detailed information.
  fun ioctl(fd : Int32, request : UInt64, ...) : Int32
end
