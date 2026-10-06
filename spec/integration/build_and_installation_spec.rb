# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "rbconfig"
require "support/phase4_fixture"
require "support/phase4_package_fixture"

RSpec.describe "BLAKE-512 checkout builds and installation" do
  include Phase4Fixture
  include Phase4PackageFixture

  describe "fresh process loading" do
    it "rejects an edited native source input" do
      with_compiled_copy do |checkout|
        source = File.join(checkout, "ext/aeos_blake512/blake512_native.c")
        File.open(source, "a") { |file| file.puts("/* harmless test edit */") }

        outcome = load_outcome(checkout)

        expect(outcome["error_class"]).to eq("Aeos::Blake512::BuildMismatch")
      end
    end

    it "rejects an edited version file" do
      with_compiled_copy do |checkout|
        version = File.join(checkout, "lib/aeos/blake512/version.rb")
        File.write(version, File.read(version).sub('VERSION = "0.1.0"', 'VERSION = "0.1.1"'))

        outcome = load_outcome(checkout)

        expect(outcome["error_class"]).to eq("Aeos::Blake512::BuildMismatch")
      end
    end

    it "rejects a changed source-input manifest" do
      with_compiled_copy do |checkout|
        manifest = File.join(checkout, "ext/aeos_blake512/source_inputs.json")
        File.open(manifest, "a") { |file| file.puts(" ") }

        outcome = load_outcome(checkout)

        expect(outcome["error_class"]).to eq("Aeos::Blake512::BuildMismatch")
      end
    end

    it "rejects a missing source-input manifest" do
      with_compiled_copy do |checkout|
        manifest = File.join(checkout, "ext/aeos_blake512/source_inputs.json")
        FileUtils.rm_f(manifest)

        outcome = load_outcome(checkout)

        expect(outcome["error_class"]).to eq("Aeos::Blake512::BuildMismatch")
      end
    end

    it "rejects malformed manifest data" do
      with_compiled_copy do |checkout|
        manifest = File.join(checkout, "ext/aeos_blake512/source_inputs.json")
        File.write(manifest, "{")

        outcome = load_outcome(checkout)

        expect(outcome["error_class"]).to eq("Aeos::Blake512::BuildMismatch")
      end
    end

    it "rejects an unsupported source-input schema" do
      with_compiled_copy do |checkout|
        manifest = File.join(checkout, "ext/aeos_blake512/source_inputs.json")
        data = File.file?(manifest) ? JSON.parse(File.read(manifest)) : { "paths" => [] }
        data["schema_version"] = 2
        File.write(manifest, JSON.generate(data))

        outcome = load_outcome(checkout)

        expect(outcome["error_class"]).to eq("Aeos::Blake512::BuildMismatch")
      end
    end

    it "rejects a duplicate source path in the manifest" do
      with_compiled_copy do |checkout|
        manifest = File.join(checkout, "ext/aeos_blake512/source_inputs.json")
        data = File.file?(manifest) ? JSON.parse(File.read(manifest)) : { "schema_version" => 1, "paths" => [] }
        data.fetch("paths") << "ext/aeos_blake512/blake512_native.c"
        data.fetch("paths") << "ext/aeos_blake512/blake512_native.c"
        File.write(manifest, JSON.generate(data))

        outcome = load_outcome(checkout)

        expect(outcome["error_class"]).to eq("Aeos::Blake512::BuildMismatch")
      end
    end

    it "rejects a parent-directory source path" do
      with_compiled_copy do |checkout|
        manifest = File.join(checkout, "ext/aeos_blake512/source_inputs.json")
        data = File.file?(manifest) ? JSON.parse(File.read(manifest)) : { "schema_version" => 1, "paths" => [] }
        data.fetch("paths") << "../outside-source.c"
        File.write(manifest, JSON.generate(data))

        outcome = load_outcome(checkout)

        expect(outcome["error_class"]).to eq("Aeos::Blake512::BuildMismatch")
      end
    end

    it "rejects a declared source symlink escaping the gem root" do
      with_compiled_copy do |checkout|
        source = File.join(checkout, "ext/aeos_blake512/blake512_core.h")
        external = File.join(File.dirname(checkout), "outside-source.h")
        FileUtils.mv(source, external)
        File.symlink(external, source)

        outcome = load_outcome(checkout)

        expect(outcome["error_class"]).to eq("Aeos::Blake512::BuildMismatch")
      end
    end

    it "rejects a missing declared source input" do
      with_compiled_copy do |checkout|
        source = File.join(checkout, "ext/aeos_blake512/blake512_core.h")
        FileUtils.rm(source)

        outcome = load_outcome(checkout)

        expect(outcome["error_class"]).to eq("Aeos::Blake512::BuildMismatch")
      end
    end

    it "rejects a previous build's native library" do
      with_compiled_copy do |checkout|
        native = File.join(checkout, "lib/aeos/blake512/blake512_native.#{RbConfig::CONFIG.fetch("DLEXT")}")
        previous_binary = File.binread(native)
        source = File.join(checkout, "ext/aeos_blake512/blake512_native.c")
        File.open(source, "a") { |file| file.puts("/* rebuild identity change */") }
        _output, _errors, rebuild = run_compile(checkout)
        raise "Fixture rebuild failed" unless rebuild.success?

        File.binwrite(native, previous_binary)

        outcome = load_outcome(checkout)

        expect(outcome["error_class"]).to eq("Aeos::Blake512::BuildMismatch")
      end
    end

    it "ignores a documentation-only edit" do
      with_compiled_copy do |checkout|
        readme = File.join(checkout, "README.md")
        File.open(readme, "a") { |file| file.puts("Documentation-only fixture edit.") }

        outcome = load_outcome(checkout)

        expect(outcome["status"]).to eq("loaded")
      end
    end

    it "keeps native LoadError for a missing library" do
      with_compiled_copy do |checkout|
        native = File.join(checkout, "lib/aeos/blake512/blake512_native.#{RbConfig::CONFIG.fetch("DLEXT")}")
        FileUtils.rm(native)

        outcome = load_outcome(checkout)

        expect(outcome["error_class"]).to eq("LoadError")
      end
    end

    it "keeps native LoadError for an unloadable library" do
      with_compiled_copy do |checkout|
        native = File.join(checkout, "lib/aeos/blake512/blake512_native.#{RbConfig::CONFIG.fetch("DLEXT")}")
        File.binwrite(native, "invalid native artifact")

        outcome = load_outcome(checkout)

        expect(outcome["error_class"]).to eq("LoadError")
      end
    end

    it "rejects a loadable native library without the identity accessor" do
      with_compiled_copy do |checkout|
        source = File.join(checkout, "ext/aeos_blake512/blake512_native.c")
        File.write(source, <<~C)
          #include "ruby.h"
          void Init_blake512_native(void) {
            VALUE aeos = rb_define_module("Aeos");
            rb_define_module_under(aeos, "Blake512");
          }
        C
        _output, _errors, rebuild = run_compile(checkout)
        raise "Fixture rebuild failed" unless rebuild.success?

        outcome = load_outcome(checkout)

        expect(outcome["error_class"]).to eq("Aeos::Blake512::BuildMismatch")
      end
    end

    it "loads from a relocated checkout without rebuilding" do
      with_compiled_copy do |checkout|
        relocated = File.join(File.dirname(checkout), "relocated")
        FileUtils.mv(checkout, relocated)

        outcome = load_outcome(relocated)

        expect(outcome["status"]).to eq("loaded")
      end
    end

    it "reports the native path under a relocated checkout" do
      with_compiled_copy do |checkout|
        relocated = File.join(File.dirname(checkout), "relocated")
        FileUtils.mv(checkout, relocated)
        native = File.join(relocated, "lib/aeos/blake512/blake512_native.#{RbConfig::CONFIG.fetch("DLEXT")}")

        info = info_outcome(relocated)

        expect(info["native_path"]).to eq(File.realpath(native))
      end
    end

    it "keeps source identity stable after relocating the whole checkout" do
      with_compiled_copy do |checkout|
        original = info_outcome(checkout)
        original_source = original.fetch("source_sha256", :missing_source_identity)
        relocated = File.join(File.dirname(checkout), "relocated")
        FileUtils.mv(checkout, relocated)

        moved = info_outcome(relocated)

        expect(moved["source_sha256"]).to eq(original_source)
      end
    end

    it "loads without compiler or Git access from a read-only source tree" do
      with_compiled_copy do |checkout|
        FileUtils.chmod_R(0o555, checkout)
        begin
          outcome = load_outcome(checkout, { "PATH" => "/nonexistent" }, File.dirname(checkout))
        ensure
          FileUtils.chmod_R(0o755, checkout)
        end

        expect(outcome["status"]).to eq("loaded")
      end
    end

    it "creates no files while requiring and hashing" do
      with_compiled_copy do |checkout|
        before = tree_snapshot(checkout)

        load_outcome(checkout)
        after = tree_snapshot(checkout)

        expect(after).to eq(before)
      end
    end
  end

  describe "checkout tasks" do
    it "provides a successful targeted clean task" do
      with_compiled_copy do |checkout|
        _output, _errors, status = run_clean(checkout)

        expect(status).to be_success
      end
    end

    it "removes the copied library on clean" do
      with_compiled_copy do |checkout|
        native = File.join(checkout, "lib/aeos/blake512/blake512_native.#{RbConfig::CONFIG.fetch("DLEXT")}")

        run_clean(checkout)

        expect(File.exist?(native)).to be_falsy
      end
    end

    it "preserves tracked source inputs on clean" do
      with_compiled_copy do |checkout|
        original = source_snapshot(checkout)

        run_clean(checkout)

        expect(source_snapshot(checkout)).to eq(original)
      end
    end

    it "anchors clean to the checkout when invoked elsewhere" do
      with_compiled_copy do |checkout|
        native = File.join(checkout, "lib/aeos/blake512/blake512_native.#{RbConfig::CONFIG.fetch("DLEXT")}")

        run_clean(checkout, File.dirname(checkout))

        expect(File.exist?(native)).to be_falsy
      end
    end

    it "preserves unrelated files during clean" do
      with_compiled_copy do |checkout|
        unrelated = File.join(checkout, "ext/aeos_blake512/user-notes.txt")
        File.write(unrelated, "leave me alone")

        run_clean(checkout)

        expect(File.read(unrelated)).to eq("leave me alone")
      end
    end

    it "removes an old copied library before a failed rebuild" do
      with_compiled_copy do |checkout|
        native = File.join(checkout, "lib/aeos/blake512/blake512_native.#{RbConfig::CONFIG.fetch("DLEXT")}")
        make = unavailable_compiler_make(File.dirname(checkout))

        run_compile(checkout, "MAKE" => make)

        expect(File.exist?(native)).to be_falsy
      end
    end

    it "records the changed source identity after a successful rebuild" do
      with_compiled_copy do |checkout|
        original = info_outcome(checkout)
        source = File.join(checkout, "ext/aeos_blake512/blake512_native.c")
        File.open(source, "a") { |file| file.puts("/* clean rebuild fixture */") }

        _output, _errors, status = run_compile(checkout)
        raise "Fixture rebuild failed" unless status.success?

        rebuilt = info_outcome(checkout)

        expect(rebuilt["source_sha256"]).not_to eq(original["source_sha256"])
      end
    end
  end

  describe "source gem" do
    it "packages the source-input manifest and identity helper" do
      with_source_copy do |checkout|
        archive = build_source_gem(checkout)
        contents = Gem::Package.new(archive).contents

        expect(contents).to include("ext/aeos_blake512/source_inputs.json", "lib/aeos/blake512/build_identity.rb")
      end
    end

    it "packages upstream source and its notice" do
      with_source_copy do |checkout|
        archive = build_source_gem(checkout)
        contents = Gem::Package.new(archive).contents

        expect(contents).to include("ext/aeos_blake512/upstream/blake512.c",
                                    "ext/aeos_blake512/upstream/LICENSE")
      end
    end

    it "excludes generated build files from the actual archive" do
      with_compiled_copy do |checkout|
        archive = build_source_gem(checkout)
        contents = Gem::Package.new(archive).contents

        expect(contents.grep(%r{\.(?:bundle|so|o)\z|/Makefile\z|generated.*\.h\z})).to be_empty
      end
    end

    it "installs from a local archive into a disposable gem home" do
      with_source_copy do |checkout|
        archive = build_source_gem(checkout)
        gem_home = File.join(File.dirname(checkout), "gem-home")

        _output, _errors, status = install_source_gem(archive, gem_home)

        expect(status).to be_success
      end
    end

    it "fails installation with an unavailable compiler" do
      with_source_copy do |checkout|
        archive = build_source_gem(checkout)
        gem_home = File.join(File.dirname(checkout), "gem-home")
        make = unavailable_compiler_make(File.dirname(checkout))

        _output, _errors, status = install_source_gem(archive, gem_home, "MAKE" => make)

        expect(status).not_to be_success
      end
    end
  end

  describe "isolated installed gem" do
    it "selects the disposable installation outside the checkout" do
      with_source_copy do |checkout|
        archive = build_source_gem(checkout)
        gem_home = File.join(File.dirname(checkout), "gem-home")
        install_source_gem(archive, gem_home)

        outcome = installed_outcome(gem_home, File.dirname(checkout))

        expect(outcome.fetch("gem_root")).to start_with(File.realpath(gem_home))
      end
    end

    it "loads its native library from the disposable installation" do
      with_source_copy do |checkout|
        archive = build_source_gem(checkout)
        gem_home = File.join(File.dirname(checkout), "gem-home")
        install_source_gem(archive, gem_home)

        outcome = installed_outcome(gem_home, File.dirname(checkout))

        expect(outcome.fetch("native_path")).to start_with(File.realpath(gem_home))
      end
    end

    it "hashes the literal abc vector from the installed gem" do
      with_source_copy do |checkout|
        archive = build_source_gem(checkout)
        gem_home = File.join(File.dirname(checkout), "gem-home")
        install_source_gem(archive, gem_home)

        outcome = installed_outcome(gem_home, File.dirname(checkout))

        expect(outcome.fetch("abc")).to eq(expected_hex_for("abc"))
      end
    end

    it "hashes the literal binary vector from the installed gem" do
      with_source_copy do |checkout|
        archive = build_source_gem(checkout)
        gem_home = File.join(File.dirname(checkout), "gem-home")
        install_source_gem(archive, gem_home)

        outcome = installed_outcome(gem_home, File.dirname(checkout))

        expect(outcome.fetch("binary")).to eq(expected_hex_for("binary_short"))
      end
    end

    it "describes the installed native file in its build identity" do
      with_source_copy do |checkout|
        archive = build_source_gem(checkout)
        gem_home = File.join(File.dirname(checkout), "gem-home")
        install_source_gem(archive, gem_home)

        outcome = installed_outcome(gem_home, File.dirname(checkout))

        expect(outcome.dig("build_info", "native_path")).to start_with(File.realpath(gem_home))
      end
    end
  end
end
