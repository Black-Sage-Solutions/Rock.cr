# The datastore module for managing all the mapped key sequences to actions.
#
# Each entry will be indexed into the underlying data structure by the key
# sequence and the included modes the sequence should be available for.
#
# Right now `KeyMap` uses Crystal's `Hash` object for simplicity reasons. In
# issue #2, this maybe changed to a more efficient data structure pertaining
# our desire for having very fast lookup and retrieval times to keep input
# latency at a minimum.
module Rock::KeyMap
  # Note: In the future, actions might receive additional context by method
  # parameters. This may include cursor, window, or pane state properties.
  alias Action = Proc(Nil)

  # TODO: find most optimal data structure for searching based on key path
  # options could be a vector, b-tree
  @@map = Hash(Bytes, Action).new

  # Add a key sequence. `mode` will restrict the key sequence to the provided
  # `Mode`. When `Rock` is in the set state, the key sequence will be
  # available.
  #
  # eg.
  # ```
  # # Add `Proc` callback:
  # KeyMap.add Mode::Insert, "\u0016" { # do something fun }
  # # or
  # KeyMap.add Mode::Insert, "\u0016" do
  #   # some fun stuff...
  # end
  #
  # # The `Proc` can be adde as an inline parameter:
  # KeyMap.add Mode::Normal, "k", &->{ cursor.up_y }
  #
  # # Object methods can also be referenced:
  # # TODO: this needs to be tested more for reference lifetime and if the
  # #       method will work with parameters.
  # KeyMap.add Mode::Visual, "k", &->up_y
  # ```
  def self.add(mode, seq, &block)
    add_to_map mode, seq, block
  end

  # Add a key sequence to multiple `Mode`s. `modes` will restrict the key
  # sequence to the provided `Mode`s. When `Rock` is in the valid states, the
  # key sequence will be available.
  #
  # eg.
  # ```
  # modes = Mode.include(:normal, :visual)
  # KeyMap.add modes, Bytes[22] do
  #   # some fun stuff...
  # end
  # ```
  def self.add(modes : Iterable(Mode), seq, &block)
    modes.each do |mode|
      add_to_map mode, seq, block
    end
  end

  # The `Mode`'s byte value will prefix the input byte sequence and be used as
  # the index value in the store.
  private def self.add_to_map(mode : Mode, seq : Bytes | String, block : Action)
    @@map[mode.to_keyseq seq] = block
  end

  # Remove a key sequence.
  #
  # eg.
  # ```
  # KeyMap.delete Mode::Normal, Byte[22]
  # KeyMap.delete Mode::Visual, "\u0016"
  # ```
  def self.delete(mode, seq)
    delete_from_map mode, seq
  end

  # Remove a key sequence from multiple modes.
  #
  # eg.
  # ```
  # KeyMap.delete Mode.include(:noraml, :visual), Byte[22]
  # ```
  def self.delete(modes : Iterable(Mode), seq)
    modes.each do |mode|
      delete_from_map mode, seq
    end
  end

  private def self.delete_from_map(mode : Mode, seq : Bytes | String)
    @@map.delete mode.to_keyseq(seq)
  end

  # Retrieve the action of a key sequence to a mode.
  #
  # eg.
  # ```
  # act = KeyMap.fetch Mode::Normal, "k"
  # act.call
  # ```
  def self.fetch(mode : Mode, seq : Bytes | String)
    @@map[mode.to_keyseq seq]
  end

  # Searches the store for related key sequences in the current set mode.
  #
  # This method will return results that are either an exact match, the
  # parameter sequence is the start of an entry, or empty if there are no
  # hits.
  def self.find_actions(seq : Bytes)
    fseq = Screen.mode.to_keyseq seq
    @@map.select do |k, v|
      k == fseq || k.to_unsafe.memcmp(fseq.to_unsafe, fseq.bytesize) == 0
    end
  end

  # Gets all the stored key sequences.
  def self.keys
    @@map.keys
  end
end
