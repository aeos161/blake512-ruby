# frozen_string_literal: true

require_relative "lib/aeos/blake512/version"

Gem::Specification.new do |spec|
  spec.name = "blake512-ruby"
  spec.version = Aeos::Blake512::VERSION
  spec.authors = ["Aeos161"]
  spec.email = ["aeos161@protonmail.com"]
  spec.summary = "Ruby gem skeleton for the original BLAKE-512 algorithm"
  spec.description = "Phase 1 project skeleton; hashing is not implemented yet."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.4"

  spec.files = %w[
    README.md CHANGELOG.md LICENSE.txt
    lib/aeos/blake512.rb lib/aeos/blake512/version.rb
    sig/aeos/blake512.rbs ext/aeos_blake512/README.md
  ]
  spec.require_paths = ["lib"]
end
