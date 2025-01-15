# Rock's centeral channel management for fiber communication.
#
#
# Broken: crystal makes it very difficult with its typing system when it comes
# to channels
module Rock::Quarry
  alias Radio = Channel
  alias RadioEvents = Radio(Terminal::Keys::Event) | Radio(Terminal::Mouse::Event)

  RADIOS = Hash(Symbol, Int32).new

  def self.add_radio(name : Symbol, radio : RadioEvents)
    RADIOS[name] = radio
  end

  def self.get_radio(name : Symbol)
    RADIOS[name]
  end

  def self.remove_radio(name : Symbol)
    RADIOS.delete(name).not_nil!
  end
end
