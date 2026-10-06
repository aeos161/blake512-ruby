# frozen_string_literal: true

require "json"

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
