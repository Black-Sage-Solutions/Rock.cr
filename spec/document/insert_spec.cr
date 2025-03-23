require "./spec_helper"

describe "Rock::Document" do
  it "creates new empty Document" do
    doc = Rock::Document.new
    doc.should_not be_nil
  end

  it "insert 1 edit to new empty Document" do
    doc = Rock::Document.new
    doc.should_not be_nil
    doc.insert 0, "Hello World!".to_slice
    content = doc.to_slice
    content.should eq "Hello World!".to_slice
  end

  it "insert a single character to new empty Document" do
    doc = Rock::Document.new
    doc.should_not be_nil
    doc.insert 0, "Hello World!".to_slice
    doc.insert 6, " ".to_slice
    doc.insert 6, "M".to_slice
    doc.insert 7, "y".to_slice
    content = doc.to_slice
    content.should eq "Hello My World!".to_slice
  end

  it "insert 2 edits to new empty Document" do
    doc = Rock::Document.new
    doc.should_not be_nil
    doc.insert 0, "Hello World!".to_slice
    doc.insert 6, "My ".to_slice
    content = doc.to_slice
    content.should eq "Hello My World!".to_slice
  end

  it "insert an edit within another edit entry of a Document" do
    doc = Rock::Document.new
    doc.should_not be_nil
    doc.insert 0, "Hello World!".to_slice
    doc.insert 6, "My ".to_slice
    doc.insert 7, "err".to_slice
    content = doc.to_slice
    content.should eq "Hello Merry World!".to_slice
  end
end
