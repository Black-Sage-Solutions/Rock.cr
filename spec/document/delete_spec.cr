require "./spec_helper.cr"

describe "Rock::Document" do
  it "removing 1 character at the start of a single entry" do
    doc = Rock::Document.new
    doc.should_not be_nil
    doc.insert 0, "Hello World!".to_slice
    doc.delete 0, 1
    content = doc.to_slice
    content.should eq "ello World!".to_slice
  end

  it "removing 1 character at the end of an entry" do
    doc = Rock::Document.new
    doc.should_not be_nil
    doc.insert 0, "Hello World!".to_slice
    doc.delete 11, 1
    content = doc.to_slice
    content.should eq "Hello World".to_slice
  end

  it "removing 1 character at the start of an entry" do
    doc = Rock::Document.new
    doc.should_not be_nil
    doc.insert 0, "Hello World! ".to_slice
    doc.insert 13, "How are you doing?\nGood?".to_slice
    doc.delete 13, 1
    content = doc.to_slice
    content.should eq "Hello World! ow are you doing?\nGood?".to_slice
  end

  it "removing 1 character at the start of an entry, arbitrary content buffer position" do
    doc = Rock::Document.new
    doc.should_not be_nil
    doc.insert 0, "Hello World! ".to_slice
    doc.insert 13, "How are you doing?".to_slice
    doc.insert 13, "Beautiful! ".to_slice
    doc.delete 13, 1
    content = doc.to_slice
    content.should eq "Hello World! eautiful! How are you doing?".to_slice
  end

  it "removing 1 character at the end of an entry, arbitrary content buffer position" do
    doc = Rock::Document.new
    doc.should_not be_nil
    doc.insert 0, "Hello World! ".to_slice
    doc.insert 13, "How are you doing?".to_slice
    doc.insert 13, "Beautiful! ".to_slice
    doc.delete 23, 1
    content = doc.to_slice
    content.should eq "Hello World! Beautiful!How are you doing?".to_slice
  end

  describe "remove a number of characters at the start of a single entry" do
    doc = Rock::Document.new
    doc.should_not be_nil
    doc.insert 0, "Hello World!".to_slice
    it "removing 2 characters" do
      doc.delete 0, 2
      content = doc.to_slice
      content.should eq "llo World!".to_slice
    end
    it "continuing to remove characters from the start" do
      doc.delete 0, 4
      content = doc.to_slice
      content.should eq "World!".to_slice
    end
  end

  describe "remove a number of characters at the end of an entry" do
    doc = Rock::Document.new
    doc.should_not be_nil
    doc.insert 0, "Hello World!".to_slice
    it "removing 3 characters" do
      doc.delete 9, 3
      content = doc.to_slice
      content.should eq "Hello Wor".to_slice
    end
    it "continuing to remove characters from the end" do
      doc.delete 5, 4
      content = doc.to_slice
      content.should eq "Hello".to_slice
    end
  end

  describe "remove a number of characters at the start of an entry, arbitrary content buffer position" do
    doc = Rock::Document.new
    doc.should_not be_nil
    doc.insert 0, "Hello World! ".to_slice
    doc.insert 13, "How are you doing?".to_slice
    doc.insert 13, "Beautiful! ".to_slice
    it "removing 5 characters" do
      doc.delete 13, 5
      content = doc.to_slice
      content.should eq "Hello World! iful! How are you doing?".to_slice
    end
    it "continuing to remove characters from the start in another entry" do
      doc.delete 19, 8
      content = doc.to_slice
      content.should eq "Hello World! iful! you doing?".to_slice
    end
  end

  describe "remove a number of characters at the end of an entry, arbitrary content buffer position" do
    doc = Rock::Document.new
    doc.should_not be_nil
    doc.insert 0, "Hello World! ".to_slice
    doc.insert 13, "How are you doing?".to_slice
    doc.insert 13, "Beautiful! ".to_slice
    it "removing 10 characters" do
      doc.delete 14, 10
      content = doc.to_slice
      content.should eq "Hello World! BHow are you doing?".to_slice
    end
    it "continuing to remove characters from the end in another entry" do
      doc.delete 23, 9
      content = doc.to_slice
      content.should eq "Hello World! BHow are y".to_slice
    end
  end

  it "removing 1 character in the middle of an entry" do
    doc = Rock::TestDocument.new
    doc.should_not be_nil
    doc.insert 0, "Hello World!".to_slice
    doc.delete 5, 1
    content = doc.to_slice
    content.should eq "HelloWorld!".to_slice
    doc.pieces.size.should eq 2
  end

  describe "remove a number of characters in an entry" do
    doc = Rock::Document.new
    doc.should_not be_nil
    doc.insert 0, "Hello World! ".to_slice
    doc.insert 13, "How are you doing?".to_slice
    doc.insert 13, "Beautiful! ".to_slice
    it "removing 7 characters" do
      doc.delete 6, 7
      content = doc.to_slice
      content.should eq "Hello Beautiful! How are you doing?".to_slice
    end
    it "continuing to remove characters from another entry" do
      doc.delete 28, 6
      content = doc.to_slice
      content.should eq "Hello Beautiful! How are you?".to_slice
    end
  end

  describe "remove a number of characters over multiple entries" do
    doc = Rock::Document.new
    doc.should_not be_nil
    doc.insert 0, "Hello World! ".to_slice
    doc.insert 13, "How are you doing?".to_slice
    doc.insert 13, "Beautiful! ".to_slice
    doc.insert 42, " Good?".to_slice
    doc.insert 48, " I'm Good!".to_slice
    it "removing 13 characters that spans 2 entries" do
      doc.delete 6, 13
      content = doc.to_slice
      content.should eq "Hello ful! How are you doing? Good? I'm Good!".to_slice
    end
    it "eliminating 1 middle entry" do
      doc.delete 6, 9
      content = doc.to_slice
      content.should eq "Hello are you doing? Good? I'm Good!".to_slice
    end
    it "eliminating multiple middle entries" do
      doc.delete 6, 21
      content = doc.to_slice
      content.should eq "Hello I'm Good!".to_slice
    end
  end
end
