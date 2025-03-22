module Rock
  class Entry
    getter line_idx : Array(Int32)
    getter src : IO::Memory
    property size : Int32
    property start : Int32

    def initialize(@src, @start, @size)
      @line_idx = Array(Int32).new

      ptr = @src.buffer + @start
      content = ptr.to_slice @size
      content.each_with_index(@start) do |b, i|
        if b == 10_u8
          @line_idx << i
        end
      end
    end

    def self.split(entry : Entry, length)
      head = Entry.new entry.src, entry.start, length
      tail = Entry.new entry.src, entry.start + length, entry.size - length
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
      @pieces << Entry.new @original, 0, @original.size unless @original.size == 0
    end

    # Returns the logical size of the document
    def size
      @pieces.reduce(0) { |acc, e| acc + e.size }
    end

    # TODO: how to memo-ize this value to reduce computation?
    def number_of_lines
      @pieces.reduce(1) { |acc, e| acc + e.line_idx.size }
    end

    def line_entries(line)
      line_count = 1
      entries = Array(Entry).new
      @pieces.each do |e|
        next_line_amount = line_count + e.line_idx.size
        if line >= line_count && line <= next_line_amount
          # Go to the next entry when the line is in the last position of the
          # entry content, since the next one would be the actual start point
          line_pos_idx = line - line_count - 1
          if line_pos_idx >= 0 && e.line_idx[line_pos_idx] == e.start + e.size - 1
            line_count = next_line_amount
            next
          end

          entries.push(e)
        end
        line_count = next_line_amount
        break if line_count > line
      end
      entries
    end

    # Gets the positional beginning and end points for the specified line
    # number.
    #
    # A tuple returns the index of the starting entry, the beginning
    # content index, the index of the ending entry, and the ending content
    # index.
    #
    # A raise `Out of bounds` exception will occur when either the beginning
    # position hasn't been found or the very last character is a new line.
    def find(line)
      next_line = line + 1

      begin_entry_idx = 0
      begin_pos = nil
      end_entry_idx = @pieces.size - 1
      end_pos = @pieces.last.start + @pieces.last.size

      if line == 1
        begin_pos = @pieces.first.start
      end

      line_count = 1
      @pieces.each_with_index do |e, i|
        next_line_amount = line_count + e.line_idx.size

        if begin_pos.nil? && line >= line_count && line <= next_line_amount
          # Go to the next entry when the line is in the last position of the
          # entry content, since the next one would be the actual start point
          line_pos_idx = line - line_count - 1
          if line_pos_idx >= 0 && e.line_idx[line_pos_idx] == e.start + e.size - 1
            begin_entry_idx = i + 1
            raise "Out of bounds" if begin_entry_idx == @pieces.size
            begin_pos = @pieces[begin_entry_idx].start
            line_count = next_line_amount
          else
            begin_entry_idx = i
            begin_pos = e.line_idx[line_pos_idx] + 1
          end
        end

        if next_line >= line_count && next_line <= next_line_amount
          next_line_pos_idx = next_line - line_count - 1
          if next_line_pos_idx >= 0
            end_entry_idx = i
            # TODO: include or exclude the line char position?
            end_pos = e.line_idx[next_line_pos_idx]
          end
        end

        line_count = next_line_amount
        break if line_count > next_line
      end

      raise "Out of bounds" if begin_pos.nil?

      return begin_entry_idx, begin_pos, end_entry_idx, end_pos
    end

    def to_slice(lines : Range)
      start = find lines.begin
      start_idx, start_pos = start[0..1]

      finish = find lines.end
      finish_idx, finish_pos = finish[2..3]

      size = 0
      @pieces[start_idx..finish_idx].each_with_index(start_idx) do |e, i|
        start = if i == start_idx
                  start_pos
                else
                  e.start
                end

        fin = if i == finish_idx
                finish_pos
              else
                start + e.size
              end

        size += fin - start
      end

      output = Bytes.new size
      logical_offset = 0
      @pieces[start_idx..finish_idx].each_with_index(start_idx) do |e, i|
        start = if i == start_idx
                  start_pos
                else
                  e.start
                end

        fin = if i == finish_idx
                finish_pos
              else
                start + e.size
              end

        bytesize = fin - start
        output_start = output.to_unsafe + logical_offset
        output_start.copy_from e.src.buffer + start, bytesize
        logical_offset += bytesize
      end
      output
    end

    def to_slice
      output = Bytes.new size
      logical_offset = 0
      @pieces.each do |e|
        output_start = output.to_unsafe + logical_offset
        output_start.copy_from e.src.buffer + e.start, e.size
        logical_offset += e.size
      end
      output
    end

    def delete(pos, length)
    end

    def insert(pos, content : Bytes)
      logical_offset = 0
      found = @pieces.each_with_index do |e, i|
        break e, i if pos < logical_offset + e.size
        logical_offset += e.size
      end

      if found.nil? && pos == logical_offset
        start = @edit.pos
        @edit.write content
        entry = Entry.new @edit, start, content.size
        @pieces << entry
        return
      end

      if found.nil?
        raise "Document: Out of Bounds for pos: '#{pos}', max bounds position is '#{logical_offset}'."
      end

      found_entry, entry_idx = found

      start = @edit.pos
      @edit.write content
      edit = Entry.new @edit, start, content.size

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

    def each_line
      LineIterator.new self
    end

    # TODO: unclear how to approach
    private class LineIterator
      include Iterator(Int32)

      @doc : Document
      @index = 0
      @line = 1

      def initialize(@doc)
      end

      def next
        loop do
          if @index < @doc.size || @line < @doc.number_of_lines
            piece = @doc.pieces[@index]
            @index += 1
          else
            return stop
          end
        end
      end
    end
  end
end
