# frozen_string_literal: true

require "json"

RSpec.describe "Aeos::Blake512::BuildIdentity" do
  describe "source-input manifest" do
    it "uses schema version 1" do
      manifest = File.expand_path("../../../../ext/aeos_blake512/source_inputs.json", __dir__)
      data = File.file?(manifest) ? JSON.parse(File.read(manifest)) : {}

      expect(data["schema_version"]).to eq(1)
    end

    it "declares the exact sorted executable build inputs" do
      manifest = File.expand_path("../../../../ext/aeos_blake512/source_inputs.json", __dir__)
      data = File.file?(manifest) ? JSON.parse(File.read(manifest)) : {}
      expected = %w[
        ext/aeos_blake512/blake512_core.h ext/aeos_blake512/blake512_core.inc
        ext/aeos_blake512/blake512_native.c ext/aeos_blake512/extconf.rb
        ext/aeos_blake512/upstream/blake.h ext/aeos_blake512/upstream/blake512.c
        lib/aeos/blake512.rb lib/aeos/blake512/build_identity.rb lib/aeos/blake512/version.rb
      ]

      expect(data["paths"]).to eq(expected)
    end
  end

  describe ".source_sha256" do
    it "uses sorted paths and eight-byte big-endian lengths for path and file bytes" do
      fixture_root = File.expand_path("../../../fixtures/build_identity", __dir__)

      actual = Aeos::Blake512::BuildIdentity.source_sha256(fixture_root)

      expect(actual).to eq("eb22736182302327aa235d5e3e10a9b5fcb2fc0908d057e63ab08d1bd634d640")
    end
  end
end
