# frozen_string_literal: true

require "digest"
require "json"
require "rbconfig"
require "tmpdir"

module Blake512SpecVectors
  PATH = File.expand_path("../../fixtures/blake512_vectors.json", __dir__)
  VECTORS = JSON.parse(File.read(PATH)).fetch("vectors")
  ABC = VECTORS.find { |vector| vector.fetch("id") == "abc" }
  BINARY_SHORT = VECTORS.find { |vector| vector.fetch("id") == "binary_short" }

  def fixture_bytes(vector)
    input = vector.fetch("input")
    return [input.fetch("hex")].pack("H*") if input.key?("hex")
    return [input.fetch("repeat_hex")].pack("H*") * input.fetch("length") if input.key?("repeat_hex")

    (0...input.fetch("sequence_mod_256")).map { |index| index % 256 }.pack("C*")
  end
end

RSpec.describe Aeos::Blake512 do
  include Blake512SpecVectors

  describe "::VERSION" do
    it "identifies the Phase 1 gem version" do
      expect(Aeos::Blake512::VERSION).to eq("0.1.0")
    end
  end

  describe "::BuildMismatch" do
    it "is a native loading error" do
      mismatch_class = described_class::BuildMismatch

      expect(mismatch_class.ancestors).to include(LoadError)
    end
  end

  describe ".build_info" do
    it "returns the agreed descriptor fields with String keys" do
      expected_keys = %w[schema_version algorithm gem_version upstream_revision source_sha256 native_sha256
                         ruby_engine ruby_api_version ruby_platform dlext compiler compile_flags native_path]

      info = described_class.build_info

      expect(info.keys).to match_array(expected_keys)
    end

    it "reports schema version 1" do
      info = described_class.build_info

      expect(info.fetch("schema_version")).to eq(1)
    end

    it "identifies the original BLAKE-512 algorithm" do
      info = described_class.build_info

      expect(info.fetch("algorithm")).to eq("blake512")
    end

    it "reports the loaded gem version" do
      info = described_class.build_info

      expect(info.fetch("gem_version")).to eq(described_class::VERSION)
    end

    it "reports the pinned upstream revision" do
      info = described_class.build_info

      expect(info.fetch("upstream_revision")).to eq("65f9ac8101191b12368e533afed6486c5b694fa3")
    end

    it "reports a lowercase source SHA-256" do
      info = described_class.build_info

      expect(info.fetch("source_sha256")).to match(/\A[0-9a-f]{64}\z/)
    end

    it "reports the SHA-256 of the loaded native file" do
      info = described_class.build_info

      expect(info.fetch("native_sha256")).to eq(Digest::SHA256.file(info.fetch("native_path")).hexdigest)
    end

    it "reports the actually loaded namespaced native path" do
      feature = $LOADED_FEATURES.find do |path|
        path.end_with?("/aeos/blake512/blake512_native.#{RbConfig::CONFIG.fetch("DLEXT")}")
      end

      info = described_class.build_info

      expect(info.fetch("native_path")).to eq(File.expand_path(feature))
    end

    it "records MRI as the build engine" do
      info = described_class.build_info

      expect(info.fetch("ruby_engine")).to eq("ruby")
    end

    it "records the build Ruby API version" do
      info = described_class.build_info

      expect(info.fetch("ruby_api_version")).to eq(RbConfig::CONFIG.fetch("ruby_version"))
    end

    it "records the build platform" do
      info = described_class.build_info

      expect(info.fetch("ruby_platform")).to eq(RbConfig::CONFIG.fetch("arch"))
    end

    it "records the native extension suffix" do
      info = described_class.build_info

      expect(info.fetch("dlext")).to eq(RbConfig::CONFIG.fetch("DLEXT"))
    end

    it "records a compiler command" do
      info = described_class.build_info

      expect(info.fetch("compiler")).to be_a(String)
    end

    it "records compile flags as String keys and values" do
      flags = described_class.build_info.fetch("compile_flags")

      pairs_are_strings = flags.all? { |key, value| key.is_a?(String) && value.is_a?(String) }

      expect(pairs_are_strings).to be_truthy
    end

    it "records compile flags in a Hash" do
      info = described_class.build_info

      expect(info.fetch("compile_flags")).to be_a(Hash)
    end

    it "freezes the outer descriptor" do
      info = described_class.build_info

      expect(info).to be_frozen
    end

    it "freezes nested compile flags" do
      flags = described_class.build_info.fetch("compile_flags")

      expect(flags).to be_frozen
    end

    it "freezes nested String values" do
      algorithm = described_class.build_info.fetch("algorithm")

      expect { algorithm.replace("changed") }.to raise_error(FrozenError)
    end

    it "freezes descriptor keys" do
      key = described_class.build_info.keys.first

      expect { key.replace("changed") }.to raise_error(FrozenError)
    end

    it "freezes nested compile flag Strings" do
      compiler_flag = described_class.build_info.fetch("compile_flags").values.first

      expect { compiler_flag.replace("changed") }.to raise_error(FrozenError)
    end

    it "retains its loaded artifact snapshot across repeated access" do
      first = described_class.build_info

      second = Dir.mktmpdir { |directory| Dir.chdir(directory) { described_class.build_info } }

      expect(second).to eq(first)
    end
  end

  describe ".digest" do
    Blake512SpecVectors::VECTORS.each do |vector|
      it "matches the independently verified #{vector.fetch("id")} vector" do
        bytes = fixture_bytes(vector)

        result = described_class.digest(bytes)

        expect(result.unpack1("H*")).to eq(vector.fetch("expected_hex"))
      end
    end

    it "returns exactly 64 bytes" do
      bytes = "abc"

      result = described_class.digest(bytes)

      expect(result.bytesize).to eq(64)
    end

    it "returns binary-encoded bytes" do
      bytes = "abc"

      result = described_class.digest(bytes)

      expect(result.encoding).to eq(Encoding::ASCII_8BIT)
    end

    it "returns a fresh String on repeated calls" do
      bytes = "abc"
      first = described_class.digest(bytes)

      second = described_class.digest(bytes)

      expect(second).not_to equal(first)
    end

    it "returns a String" do
      bytes = "abc"

      result = described_class.digest(bytes)

      expect(result).to be_a(String)
    end

    it "accepts a String subclass" do
      string_class = Class.new(String)
      bytes = string_class.new("abc")

      result = described_class.digest(bytes)

      expect(result.unpack1("H*")).to eq(Blake512SpecVectors::ABC.fetch("expected_hex"))
    end

    it "rejects nil with TypeError" do
      bytes = nil

      expect { described_class.digest(bytes) }.to raise_error(TypeError)
    end

    it "rejects numbers with TypeError" do
      bytes = 123

      expect { described_class.digest(bytes) }.to raise_error(TypeError)
    end

    it "does not implicitly call to_str" do
      bytes = Object.new
      def bytes.to_str
        "abc"
      end

      expect { described_class.digest(bytes) }.to raise_error(TypeError)
    end

    it "does not implicitly call to_s" do
      bytes = Object.new
      def bytes.to_s
        "abc"
      end

      expect { described_class.digest(bytes) }.to raise_error(TypeError)
    end

    it "accepts frozen input" do
      bytes = +"abc"
      bytes.freeze

      result = described_class.digest(bytes)

      expect(result.unpack1("H*")).to eq(Blake512SpecVectors::ABC.fetch("expected_hex"))
    end

    it "does not mutate caller bytes" do
      bytes = [0, 255, 128, 127, 0, 254, 129, 130].pack("C*")
      original = bytes.dup

      described_class.digest(bytes)

      expect(bytes).to eq(original)
    end

    it "hashes invalid UTF-8 as exact bytes" do
      bytes = [0, 255, 128, 127, 0, 254, 129, 130].pack("C*").force_encoding(Encoding::UTF_8)

      result = described_class.digest(bytes)

      expect(result.unpack1("H*")).to eq(Blake512SpecVectors::BINARY_SHORT.fetch("expected_hex"))
    end

    it "preserves an earlier output across interleaved calls" do
      first = described_class.digest("abc")

      described_class.digest("different bytes")
      GC.start

      expect(first.unpack1("H*")).to eq(Blake512SpecVectors::ABC.fetch("expected_hex"))
    end

    it "returns the same answer after interleaved calls" do
      described_class.digest("abc")
      described_class.digest("different bytes")

      result = described_class.digest("abc")

      expect(result.unpack1("H*")).to eq(Blake512SpecVectors::ABC.fetch("expected_hex"))
    end

    it "does not change the caller's encoding" do
      bytes = [0, 255, 128].pack("C*").force_encoding(Encoding::UTF_8)

      described_class.digest(bytes)

      expect(bytes.encoding).to eq(Encoding::UTF_8)
    end
  end

  describe ".hexdigest" do
    Blake512SpecVectors::VECTORS.each do |vector|
      it "matches the independently verified #{vector.fetch("id")} vector" do
        bytes = fixture_bytes(vector)

        result = described_class.hexdigest(bytes)

        expect(result).to eq(vector.fetch("expected_hex"))
      end
    end

    it "returns exactly 128 lowercase ASCII hex characters" do
      bytes = "abc"

      result = described_class.hexdigest(bytes)

      expect(result).to match(/\A[0-9a-f]{128}\z/)
    end

    it "accepts a String subclass" do
      string_class = Class.new(String)
      bytes = string_class.new("abc")

      result = described_class.hexdigest(bytes)

      expect(result).to eq(Blake512SpecVectors::ABC.fetch("expected_hex"))
    end

    it "returns a String" do
      bytes = "abc"

      result = described_class.hexdigest(bytes)

      expect(result).to be_a(String)
    end

    it "rejects nil with TypeError" do
      bytes = nil

      expect { described_class.hexdigest(bytes) }.to raise_error(TypeError)
    end

    it "rejects numbers with TypeError" do
      bytes = 123

      expect { described_class.hexdigest(bytes) }.to raise_error(TypeError)
    end

    it "does not implicitly call to_str" do
      bytes = Object.new
      def bytes.to_str
        "abc"
      end

      expect { described_class.hexdigest(bytes) }.to raise_error(TypeError)
    end

    it "does not implicitly call to_s" do
      bytes = Object.new
      def bytes.to_s
        "abc"
      end

      expect { described_class.hexdigest(bytes) }.to raise_error(TypeError)
    end

    it "accepts frozen input" do
      bytes = +"abc"
      bytes.freeze

      result = described_class.hexdigest(bytes)

      expect(result).to eq(Blake512SpecVectors::ABC.fetch("expected_hex"))
    end

    it "does not mutate caller bytes" do
      bytes = [0, 255, 128, 127, 0, 254, 129, 130].pack("C*")
      original = bytes.dup

      described_class.hexdigest(bytes)

      expect(bytes).to eq(original)
    end

    it "hashes invalid UTF-8 as exact bytes" do
      bytes = [0, 255, 128, 127, 0, 254, 129, 130].pack("C*").force_encoding(Encoding::UTF_8)

      result = described_class.hexdigest(bytes)

      expect(result).to eq(Blake512SpecVectors::BINARY_SHORT.fetch("expected_hex"))
    end

    it "returns the same answer after interleaved calls" do
      described_class.hexdigest("abc")
      described_class.hexdigest("different bytes")

      result = described_class.hexdigest("abc")

      expect(result).to eq(Blake512SpecVectors::ABC.fetch("expected_hex"))
    end

    it "does not change the caller's encoding" do
      bytes = [0, 255, 128].pack("C*").force_encoding(Encoding::UTF_8)

      described_class.hexdigest(bytes)

      expect(bytes.encoding).to eq(Encoding::UTF_8)
    end
  end
end
