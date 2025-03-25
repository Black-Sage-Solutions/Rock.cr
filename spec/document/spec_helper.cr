require "../spec_helper.cr"
require "../../src/rock/document"

# Exposes `Rock::Document`'s internals.
class Rock::TestDocument < Rock::Document
  getter pieces
end

