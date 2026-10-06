# frozen_string_literal: true

require "digest"
require "json"
require "rbconfig"

module Aeos
  module Blake512
    # Shared source identity for extconf and the loader. Each sorted record is:
    # uint64_be(path.bytesize), path bytes, uint64_be(file.bytesize), file bytes.
    module BuildIdentity
      class InvalidSource < StandardError; end

      MANIFEST_PATH = "ext/aeos_blake512/source_inputs.json"
      UPSTREAM_REVISION = "65f9ac8101191b12368e533afed6486c5b694fa3"
      EMBEDDED_KEYS = %w[schema_version algorithm gem_version upstream_revision source_sha256
                         ruby_engine ruby_api_version ruby_platform dlext compiler compile_flags
                         source_paths].freeze

      def self.paths(root)
        data = JSON.parse(source_bytes(root, MANIFEST_PATH))
        raise InvalidSource, "invalid source-input manifest" unless data.is_a?(Hash) && data["schema_version"] == 1

        paths = data["paths"]
        raise InvalidSource, "invalid source-input manifest" unless valid_paths?(paths)

        paths
      rescue JSON::ParserError => e
        raise InvalidSource, "invalid source-input manifest: #{e.message}"
      end

      def self.valid_paths?(paths)
        paths.is_a?(Array) && paths.all? { |path| valid_path?(path) } &&
          paths == paths.sort && paths == paths.uniq
      end

      def self.source_sha256(root)
        digest = Digest::SHA256.new
        (paths(root) + [MANIFEST_PATH]).sort.each do |path|
          bytes = source_bytes(root, path)
          digest.update([path.bytesize].pack("Q>"))
          digest.update(path)
          digest.update([bytes.bytesize].pack("Q>"))
          digest.update(bytes)
        end
        digest.hexdigest
      end

      def self.native_path(features)
        suffix = "/aeos/blake512/blake512_native.#{RbConfig::CONFIG.fetch("DLEXT")}"
        matches = features.select { |feature| feature.end_with?(suffix) }
        raise InvalidSource, "native feature is not unique" unless matches.length == 1

        File.realpath(matches.first)
      rescue SystemCallError => e
        raise InvalidSource, "native feature unavailable: #{e.message}"
      end

      def self.validated_info(root, raw_identity, version, native_path)
        raise InvalidSource, "invalid embedded identity" unless raw_identity.is_a?(String)

        embedded = JSON.parse(raw_identity)
        validate_embedded!(embedded, root, version)
        info = embedded.reject { |key, _value| key == "source_paths" }
        info["native_path"] = native_path
        info["native_sha256"] = Digest::SHA256.file(native_path).hexdigest
        deep_freeze(info)
      rescue JSON::ParserError, SystemCallError => e
        raise InvalidSource, "invalid native identity: #{e.message}"
      end

      def self.validate_embedded!(data, root, version)
        raise InvalidSource, "invalid embedded identity" unless data.is_a?(Hash) && data.keys.sort == EMBEDDED_KEYS.sort

        expected_identity(root, version).each do |field, value|
          raise InvalidSource, "#{field} mismatch" unless data[field] == value
        end

        raise InvalidSource, "invalid build platform" unless data["ruby_platform"].is_a?(String)

        validate_compiler!(data)
      end

      def self.expected_identity(root, version)
        {
          "schema_version" => 1, "algorithm" => "blake512", "gem_version" => version,
          "upstream_revision" => UPSTREAM_REVISION, "ruby_engine" => RUBY_ENGINE,
          "ruby_api_version" => RbConfig::CONFIG.fetch("ruby_version"),
          "dlext" => RbConfig::CONFIG.fetch("DLEXT"), "source_paths" => paths(root),
          "source_sha256" => source_sha256(root)
        }
      end

      def self.validate_compiler!(data)
        raise InvalidSource, "invalid compiler metadata" unless data["compiler"].is_a?(String)

        flags = data["compile_flags"]
        raise InvalidSource, "invalid compiler flags" unless flags.is_a?(Hash) && !flags.empty?

        return if flags.all? { |key, value| key.is_a?(String) && value.is_a?(String) }

        raise InvalidSource, "invalid compiler flags"
      end

      def self.source_bytes(root, path)
        raise InvalidSource, "invalid source path" unless valid_path?(path)

        real_root = File.realpath(root)
        real_file = File.realpath(File.join(real_root, path))
        raise InvalidSource, "source escapes gem root" unless real_file.start_with?("#{real_root}/")
        raise InvalidSource, "source is not a regular file" unless File.file?(real_file)

        File.binread(real_file)
      rescue SystemCallError => e
        raise InvalidSource, "source unavailable: #{e.message}"
      end

      def self.valid_path?(path)
        return false unless path.is_a?(String)
        return false if path.empty? || path.start_with?("/") || path.include?("\\") || path.include?("\0")

        path.split("/", -1).all? { |segment| valid_segment?(segment) }
      end

      def self.valid_segment?(segment)
        !segment.empty? && segment != "." && segment != ".."
      end

      def self.deep_freeze(value)
        case value
        when Hash
          value.each_key { |key| deep_freeze(key) }
          value.each_value { |item| deep_freeze(item) }
        when Array then value.each { |item| deep_freeze(item) }
        end
        value.freeze
      end
    end
  end
end
