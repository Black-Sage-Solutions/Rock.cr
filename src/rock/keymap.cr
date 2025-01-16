module Rock::KeyMap
  # TODO: mode check
  # Note: In the future may want to provide context to the action callbacks
  alias Action = Proc(Nil)

  # TODO: find most optimal data structure for searching based on key path
  # options could be a vector, b-tree
  @@map = Hash(Bytes, Action).new

  # Would need to add `extend self` to the module for the delegate macro to work, I think
  # delegate :[], :[]?, :[]=, :delete, :fetch, :has_key?, :keys, :select, :size, to: @@map

  def self.add(name : String, &block : Action)
    @@map[name.to_slice] = block
  end

  def self.[](name : String) : Action
    @@map[name.to_slice]
  end

  def self.[](seq : Bytes) : Action
    @@map[seq]
  end

  def self.delete(name : String)
    @@map.delete name.to_slice
  end

  def self.delete(seq : Bytes)
    @@map.delete seq
  end

  def self.find_actions(seq : Bytes)
    @@map.select do |k, v|
      k == seq || k.to_unsafe.memcmp(seq.to_unsafe, seq.bytesize) == 0
    end
  end
end
