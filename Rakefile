# frozen_string_literal: true

require "fileutils"
require "rbconfig"
require "rspec/core/rake_task"

ROOT = File.expand_path(__dir__)
EXTENSION_DIR = File.join(ROOT, "ext/aeos_blake512")
DLEXT = RbConfig::CONFIG.fetch("DLEXT")
EXTENSION_NAME = "blake512_native.#{DLEXT}"
INSTALLED_EXTENSION = File.join(ROOT, "lib/aeos/blake512", EXTENSION_NAME)
BUILD_OUTPUTS = %w[Makefile mkmf.log generated_build_identity.h blake512_native.o .sitearchdir.time].map do |name|
  File.join(EXTENSION_DIR, name)
end.freeze

task :clean do
  outputs = BUILD_OUTPUTS + [File.join(EXTENSION_DIR, EXTENSION_NAME), INSTALLED_EXTENSION]
  (outputs + ["#{INSTALLED_EXTENSION}.tmp"]).each do |path|
    FileUtils.rm_f(path)
  end
end

task :compile do
  Rake::Task[:clean].invoke
  Dir.chdir(EXTENSION_DIR) do
    sh RbConfig.ruby, "extconf.rb"
    sh ENV.fetch("MAKE", "make")
  end

  FileUtils.mkdir_p(File.dirname(INSTALLED_EXTENSION))
  FileUtils.cp(File.join(EXTENSION_DIR, EXTENSION_NAME), "#{INSTALLED_EXTENSION}.tmp")
  File.rename("#{INSTALLED_EXTENSION}.tmp", INSTALLED_EXTENSION)
ensure
  FileUtils.rm_f("#{INSTALLED_EXTENSION}.tmp")
end

RSpec::Core::RakeTask.new(:spec)
task spec: :compile
task default: :spec
