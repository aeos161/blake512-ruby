# frozen_string_literal: true

require "json"
require "open3"
require "rbconfig"
require "rubygems/package"
require "support/phase4_fixture"

module Phase4PackageFixture
  VECTORS = JSON.parse(
    File.read(File.join(Phase4Fixture::SOURCE_ROOT, "spec/fixtures/blake512_vectors.json"))
  ).fetch("vectors")
  INSTALLED_SCRIPT = <<~RUBY
    require "json"
    gem "blake512-ruby", "0.1.0"
    require "aeos/blake512"
    native = $LOADED_FEATURES.find { |path| path.include?("/aeos/blake512/blake512_native.") }
    binary = [0, 255, 128, 127, 0, 254, 129, 130].pack("C*")
    info = Aeos::Blake512.respond_to?(:build_info) ? Aeos::Blake512.build_info : nil
    puts JSON.generate(
      "gem_root" => Gem.loaded_specs.fetch("blake512-ruby").full_gem_path,
      "native_path" => native,
      "abc" => Aeos::Blake512.hexdigest("abc"),
      "binary" => Aeos::Blake512.hexdigest(binary),
      "build_info" => info
    )
  RUBY

  def build_source_gem(checkout)
    archive = File.join(File.dirname(checkout), "blake512-ruby-0.1.0.gem")
    command = [RbConfig.ruby, "-S", "gem", "build", "blake512-ruby.gemspec", "--output", archive]
    output, errors, status = Open3.capture3(Phase4Fixture::CHILD_ENV, *command, chdir: checkout)
    raise "Source gem build failed: #{output}\n#{errors}" unless status.success?

    archive
  end

  def install_source_gem(archive, gem_home, environment = {})
    command = [RbConfig.ruby, "-S", "gem", "install", "--local", "--no-document",
               "--install-dir", gem_home, archive]
    Open3.capture3(Phase4Fixture::CHILD_ENV.merge(environment), *command, chdir: File.dirname(archive))
  end

  def installed_outcome(gem_home, working_directory)
    environment = Phase4Fixture::CHILD_ENV.merge("GEM_HOME" => gem_home, "GEM_PATH" => gem_home)
    output, errors, status = Open3.capture3(environment, RbConfig.ruby, "-e", INSTALLED_SCRIPT,
                                            chdir: working_directory)
    raise "Installed gem load failed: #{errors}" unless status.success?

    JSON.parse(output)
  end

  def expected_hex_for(id)
    VECTORS.find { |vector| vector.fetch("id") == id }.fetch("expected_hex")
  end
end
