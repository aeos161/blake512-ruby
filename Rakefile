# frozen_string_literal: true

require "fileutils"
require "rbconfig"
require "rspec/core/rake_task"

task :compile do
  Dir.chdir("ext/aeos_blake512") do
    sh RbConfig.ruby, "extconf.rb"
    sh ENV.fetch("MAKE", "make"), "clean"
    sh ENV.fetch("MAKE", "make")
  end

  extension = "blake512_native.#{RbConfig::CONFIG.fetch("DLEXT")}"
  FileUtils.mkdir_p("lib/aeos/blake512")
  FileUtils.cp("ext/aeos_blake512/#{extension}", "lib/aeos/blake512/#{extension}")
end

RSpec::Core::RakeTask.new(:spec)
task spec: :compile
task default: :spec
