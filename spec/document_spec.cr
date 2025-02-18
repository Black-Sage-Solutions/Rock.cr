require "spec"
require "./spec_helper"
require "../src/rock/document"

describe "Rock::Document" do
  it "creates new empty Document" do
    doc = Rock::Document.new
    doc.should_not be_nil
  end

  it "add 1 edit to new empty Document" do
    doc = Rock::Document.new
    doc.should_not be_nil
    doc.new_edit
    doc.write "Hello World!".to_slice
    doc.apply
    content = doc.to_slice
    content.should eq "Hello World!".to_slice
  end

  it "add 2 edits to new empty Document" do
    doc = Rock::Document.new
    doc.should_not be_nil
    doc.new_edit
    doc.write "Hello World!".to_slice
    doc.apply
    doc.new_edit 6
    doc.write "My ".to_slice
    doc.apply
    content = doc.to_slice
    content.should eq "Hello My World!".to_slice
  end

  it "add edit within an edit entry of a Document" do
    doc = Rock::Document.new
    doc.should_not be_nil
    doc.write "Hello World!".to_slice
    doc.apply
    doc.new_edit 6
    doc.write "My ".to_slice
    doc.apply
    doc.new_edit 7
    doc.write "err".to_slice
    doc.apply
    content = doc.to_slice
    content.should eq "Hello Merry World!".to_slice
  end
end

