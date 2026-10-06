# frozen_string_literal: true

require_relative "blake512/version"
require_relative "blake512/build_identity"

module Aeos
  # Final original BLAKE-512 hashing of exact String bytes.
  module Blake512
    class BuildMismatch < LoadError; end
  end
end

require "aeos/blake512/blake512_native"

module Aeos
  # Public native BLAKE-512 API and validated build descriptor.
  module Blake512
    def self.hexdigest(bytes)
      digest(bytes).unpack1("H*")
    end

    def self.build_info
      @build_info
    end

    begin
      unless respond_to?(:__native_build_identity, true)
        raise BuildMismatch, "native build identity missing; rebuild the extension"
      end

      root = File.expand_path("../..", __dir__)
      path = BuildIdentity.native_path($LOADED_FEATURES)
      @build_info = BuildIdentity.validated_info(root, __send__(:__native_build_identity), VERSION, path)
    rescue BuildIdentity::InvalidSource => e
      raise BuildMismatch, "#{e.message}; rebuild the extension"
    end
  end
end
