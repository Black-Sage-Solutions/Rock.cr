module Rock
  enum EntryKind
    Original
    Edit
  end

  class Entry
    getter location : EntryKind
    property size : Int32
    property start : Int32

    def initialize(@location, @start, @size)
    end

    def self.split(entry : Entry, length)
      head = Entry.new entry.location, entry.start, length
      tail = Entry.new entry.location, entry.start + length, entry.size - length
      {head, tail}
    end
  end

  class Document
    @edit : IO::Memory
    @original : IO::Memory
    @pieces = Array(Entry).new

    def initialize(file = nil)
      @edit = IO::Memory.new
      @original = IO::Memory.new
      @pieces << Entry.new EntryKind::Original, 0, @original.size unless @original.size == 0
    end

    # Returns the logical size of the document
    def size
      @pieces.reduce(0) { |acc, e| acc + e.size }
    end

    def to_slice
      output = Bytes.new size
      logical_offset = 0
      @pieces.each do |e|
        src = case e.location
              in .original?
                @original
              in .edit?
                @edit
              end
        output_start = output.to_unsafe + logical_offset
        output_start.copy_from src.buffer + e.start, e.size
        logical_offset += e.size
      end
      output
    end

    def insert(pos, content : Bytes)
      logical_offset = 0
      found = @pieces.each_with_index do |e, i|
        break e, i if pos < logical_offset + e.size
        logical_offset += e.size
      end

      if found.nil? && pos == logical_offset
        entry = Entry.new EntryKind::Edit, pos, content.size
        @edit.write content
        @pieces << entry
        return
      end

      if found.nil?
        raise "Document: Out of Bounds for pos: '#{pos}', max bounds position is '#{logical_offset}'."
      end

      found_entry, entry_idx = found

      edit = Entry.new EntryKind::Edit, @edit.pos, content.size
      @edit.write content

      if pos == logical_offset
        @pieces.insert entry_idx, edit
      else
        head, tail = Entry.split found_entry, pos - logical_offset
        @pieces.insert_all entry_idx, {head, edit, tail}
        @pieces.delete_at entry_idx + 3
      end
    end

    # Save the changes to the file
    def save
    end
  end
end
