# frozen_string_literal: true

require "mkmf"
require "json"
require_relative "../../lib/aeos/blake512/build_identity"
require_relative "../../lib/aeos/blake512/version"

ROOT = File.expand_path("../..", __dir__)
IDENTITY = Aeos::Blake512::BuildIdentity

create_makefile("aeos/blake512/blake512_native")

variables = File.readlines("Makefile").each_with_object({}) do |line, values|
  match = line.chomp.match(/\A([A-Za-z_][A-Za-z_0-9]*)\s*=\s*(.*)\z/)
  values[match[1]] = match[2] if match
end

def make_value(name, variables, seen = [])
  return "" if seen.include?(name)

  variables.fetch(name, "").gsub(/\$\(([A-Za-z_][A-Za-z_0-9]*)\)/) do
    make_value(Regexp.last_match(1), variables, seen + [name])
  end
end

flags = %w[CFLAGS CPPFLAGS INCFLAGS LDFLAGS DLDFLAGS LIBS LOCAL_LIBS].to_h do |name|
  [name.downcase, make_value(name, variables)]
end
identity = {
  "schema_version" => 1,
  "algorithm" => "blake512",
  "gem_version" => Aeos::Blake512::VERSION,
  "upstream_revision" => IDENTITY::UPSTREAM_REVISION,
  "source_sha256" => IDENTITY.source_sha256(ROOT),
  "source_paths" => IDENTITY.paths(ROOT),
  "ruby_engine" => RUBY_ENGINE,
  "ruby_api_version" => RbConfig::CONFIG.fetch("ruby_version"),
  "ruby_platform" => RbConfig::CONFIG.fetch("arch"),
  "dlext" => RbConfig::CONFIG.fetch("DLEXT"),
  "compiler" => make_value("CC", variables),
  "compile_flags" => flags
}
bytes = JSON.generate(identity).bytes
hex_bytes = bytes.each_slice(16).map do |slice|
  encoded = slice.map { |byte| format("0x%02x", byte) }.join(", ")
  "  #{encoded}"
end
header = "static const unsigned char aeos_build_identity_json[] = {\n#{hex_bytes.join(",\n")}\n};\n"
File.write("generated_build_identity.h", header)
