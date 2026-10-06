# frozen_string_literal: true

require "fileutils"
require "digest"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

module Phase4Fixture
  SOURCE_ROOT = File.expand_path("../..", __dir__)
  CHILD_ENV = {
    "BUNDLE_BIN_PATH" => nil, "BUNDLE_GEMFILE" => nil, "RUBYOPT" => nil,
    "RUBYLIB" => nil, "GEM_HOME" => nil, "GEM_PATH" => nil,
    "RUBYGEMS_GEMDEPS" => nil
  }.freeze
  LOAD_SCRIPT = <<~RUBY
    require "json"
    begin
      require "aeos/blake512"
      Aeos::Blake512.hexdigest("abc") if Aeos::Blake512.respond_to?(:digest)
      puts JSON.generate("status" => "loaded", "version" => Aeos::Blake512::VERSION)
    rescue LoadError => error
      puts JSON.generate("status" => "load_error", "error_class" => error.class.name)
    end
  RUBY
  INFO_SCRIPT = <<~RUBY
    require "json"
    require "aeos/blake512"
    info = Aeos::Blake512.respond_to?(:build_info) ? Aeos::Blake512.build_info : {}
    puts JSON.generate(info)
  RUBY

  def with_source_copy
    Dir.mktmpdir("blake512-phase4-") do |temporary|
      checkout = File.join(temporary, "checkout")
      FileUtils.mkdir_p(checkout)
      copy_source_files(checkout)
      yield checkout
    end
  end

  def copy_source_files(checkout)
    gemspec = Gem::Specification.load(File.join(SOURCE_ROOT, "blake512-ruby.gemspec"))
    source_paths = gemspec.files + %w[Rakefile Gemfile blake512-ruby.gemspec]
    source_paths.each do |relative_path|
      destination = File.join(checkout, relative_path)
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(File.join(SOURCE_ROOT, relative_path), destination)
    end
  end

  def with_compiled_copy
    with_source_copy do |checkout|
      output, errors, status = run_compile(checkout)
      raise "Fixture compile failed: #{output}\n#{errors}" unless status.success?

      yield checkout
    end
  end

  def run_compile(checkout, environment = {})
    Open3.capture3(CHILD_ENV.merge(environment), RbConfig.ruby, "-S", "rake", "compile", chdir: checkout)
  end

  def run_clean(checkout, working_directory = checkout)
    rakefile = File.join(checkout, "Rakefile")
    Open3.capture3(CHILD_ENV, RbConfig.ruby, "-S", "rake", "-f", rakefile, "clean", chdir: working_directory)
  end

  def load_outcome(checkout, environment = {}, working_directory = checkout)
    command = [RbConfig.ruby, "-I", File.join(checkout, "lib"), "-e", LOAD_SCRIPT]
    output, errors, status = Open3.capture3(CHILD_ENV.merge(environment), *command, chdir: working_directory)
    raise "Fresh load failed unexpectedly: #{errors}" unless status.success?

    JSON.parse(output)
  end

  def info_outcome(checkout)
    command = [RbConfig.ruby, "-I", File.join(checkout, "lib"), "-e", INFO_SCRIPT]
    output, errors, status = Open3.capture3(CHILD_ENV, *command, chdir: checkout)
    raise "Build identity load failed: #{errors}" unless status.success?

    JSON.parse(output)
  end

  def unavailable_compiler_make(temporary)
    wrapper = File.join(temporary, "make-without-compiler")
    File.write(wrapper, "#!/bin/sh\nexec make CC=/nonexistent/blake512-compiler \"$@\"\n")
    FileUtils.chmod(0o755, wrapper)
    wrapper
  end

  def tree_snapshot(checkout)
    paths = Dir.glob(File.join(checkout, "**", "*"), File::FNM_DOTMATCH).select { |path| File.file?(path) }
    paths.to_h { |path| [path.delete_prefix("#{checkout}/"), Digest::SHA256.file(path).hexdigest] }
  end

  def source_snapshot(checkout)
    gemspec = Gem::Specification.load(File.join(SOURCE_ROOT, "blake512-ruby.gemspec"))
    paths = gemspec.files + %w[Rakefile Gemfile blake512-ruby.gemspec]
    paths.to_h do |path|
      source = File.join(checkout, path)
      [path, File.file?(source) ? Digest::SHA256.file(source).hexdigest : nil]
    end
  end
end
