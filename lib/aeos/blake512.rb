# frozen_string_literal: true

require_relative "blake512/version"
require "aeos/blake512/blake512_native"

module Aeos
  # Final original BLAKE-512 hashing of exact String bytes.
  module Blake512
    def self.hexdigest(bytes)
      digest(bytes).unpack1("H*")
    end
  end
end
