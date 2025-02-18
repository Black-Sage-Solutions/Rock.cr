module Rock
  enum EntryKind
    Original
    Edit
  end

  class Entry
    getter location : EntryKind
    getter chronology : Int32
    property start : Int32
    property length : Int32
    property content : Bytes
    property new_lines_idx = Array(Int32).new

    def initialize(@location, @start, @chronology, @content)
      @length = @content.size
    end

    delegate :size, to: @content

    def self.split(entry : Entry, start, length, chronology)
      offset = start - entry.start
      head = Entry.new entry.location, entry.start, chronology, entry.content[...offset]
      tail = Entry.new entry.location, start + length, chronology, entry.content[offset..]
      {head, tail}
    end
  end

  class Document
    @edit_content : IO::Memory
    @edit_pos : Int32
    @original : IO::Memory
    @chrono_count = 0
    @pieces = Array(Entry).new

    def initialize(file = nil)
      @edit_content = IO::Memory.new
      @edit_pos = 0
      @original = IO::Memory.new
      @pieces << Entry.new EntryKind::Original, 0, @chrono_count, @original.to_slice
      @chrono_count += 1
    end

    delegate :write, to: @edit_content

    def to_slice
      last = @pieces.last
      buf = Bytes.new last.start + last.length
      @pieces.each do |e|
        pos = buf.to_unsafe + e.start
        pos.copy_from e.content.to_unsafe, e.length
      end
      buf
    end

    def new_edit(pos)
      @edit_content = IO::Memory.new
      @edit_pos = pos
    end

    def new_edit
      new_edit @pieces.last.start + @pieces.last.length
    end

    def new_edit(col, row)
      start = col * row
      new_edit start
    end

    def apply
      return if @edit_content.size == 0
      i = @pieces.index { |e| @edit_pos > e.start && @edit_pos < (e.start + e.length) }
      edit_entry = Entry.new EntryKind::Edit, @edit_pos, @chrono_count, @edit_content.to_slice
      if i.nil?
        @pieces << edit_entry
        @chrono_count += 1
        return
      end
      entry = @pieces.delete_at i
      head, tail = Entry.split entry, edit_entry.start, edit_entry.length, @chrono_count
      @chrono_count += 1
      if i < @pieces.size
        @pieces.insert i, head
        @pieces.insert i + 1, edit_entry
        @pieces.insert i + 2, tail
      else
        @pieces.push head, edit_entry, tail
      end
      @pieces.each(within: (i + 3)..) { |e| e.start += edit_entry.length }
    end

    # Save the changes to the file
    def save
    end
  end
end
