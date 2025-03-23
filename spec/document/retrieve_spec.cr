require "./spec_helper"

describe "Rock::Document" do
  describe "get a range of lines from a Document" do
    doc = Rock::Document.new
    doc.should_not be_nil
    doc.insert 0, "Hello World!\n".to_slice
    doc.insert 13, "This is mine.".to_slice
    doc.insert 13, "How are you doing?\nAre you doing well?\nGood? ".to_slice

    ranges = [
      {
        lines:    1..4,
        expected: <<-E
          Hello World!
          How are you doing?
          Are you doing well?
          Good? This is mine.
          E
      },
      {
        lines:    2..4,
        expected: <<-E
          How are you doing?
          Are you doing well?
          Good? This is mine.
          E
      },
      {
        lines:    1..3,
        expected: <<-E
          Hello World!
          How are you doing?
          Are you doing well?
          E
      },
      {
        lines:    2..3,
        expected: <<-E
          How are you doing?
          Are you doing well?
          E
      },
      {
        lines:    2..2,
        expected: <<-E
          How are you doing?
          E
      },
    ]

    ranges.each do |r|
      it "retrieve lines #{r[:lines]}" do
        content = doc.to_slice r[:lines]
        content.should eq r[:expected].to_slice
      end
    end

    # TODO: need case for out of bounds for seeing the practicality
  end

  describe "get the entries for a specfic line from a Document" do
    doc = Rock::Document.new
    doc.should_not be_nil
    doc.insert 0, "Hello World! ".to_slice
    doc.insert 13, "This is mine. ".to_slice
    doc.insert 27, "How are you doing?\nAre you doing well?\nGood? ".to_slice
    doc.insert 72, "Continuing on ".to_slice
    doc.insert 86, "with this data, including more entries ".to_slice
    doc.insert 125, "that will ".to_slice
    doc.insert 135, "help include more test\n".to_slice
    doc.insert 158, "cases.".to_slice

    test_cases = [
      {
        line:            2,
        expected_amount: 1,
      },
      {
        line:            1,
        expected_amount: 3,
      },
      {
        line:            3,
        expected_amount: 5,
      },
      # Rare case when the line position is last in the entry content sequence
      # and the `Document` should skip including the entry
      {
        line:            4,
        expected_amount: 1,
      },
      {
        line:            5,
        expected_amount: 0,
      },
    ]

    test_cases.each do |t|
      it "retrieve line ##{t[:line]} entries" do
        entries = doc.line_entries t[:line]
        entries.size.should eq t[:expected_amount]
      end
    end

    # TODO: need case for out of bounds for seeing the practicality
  end

  describe "get the coordinates of a specfic line from a Document" do
    doc = Rock::Document.new
    doc.should_not be_nil
    doc.insert 0, "Hello World! ".to_slice
    doc.insert 13, "This is mine. ".to_slice
    doc.insert 27, "How are you doing?\nAre you doing well?\nGood? ".to_slice
    doc.insert 72, "Continuing on ".to_slice
    doc.insert 86, "with this data, including more entries ".to_slice
    doc.insert 125, "that will ".to_slice
    doc.insert 135, "help include more test\n".to_slice
    doc.insert 158, "cases.".to_slice

    test_cases = [
      {
        line:            1,
        expected_result: {0, 0, 2, 45},
      },
      {
        line:            2,
        expected_result: {2, 46, 2, 65},
      },
      {
        line:            3,
        expected_result: {2, 66, 6, 157},
      },
      {
        line:            4,
        expected_result: {7, 158, 7, 164},
      },
    ]

    test_cases.each do |t|
      it "retrieve line ##{t[:line]}" do
        data = doc.find t[:line]
        data.should eq t[:expected_result]
      end
    end

    # TODO: need a case to test the exceptions raised from
    # `Rock::Document#find` and see the practicality
  end
end
