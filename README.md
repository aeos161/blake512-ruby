# blake512-ruby

This is a standalone MRI gem in development for the final
original BLAKE-512 algorithm. The gem name is `blake512-ruby`; its Ruby entrypoint
is `require "aeos/blake512"`, and its namespace is `Aeos::Blake512`. The version
is `0.1.0`. **Hashing is not implemented yet.** The planned public operations are
`Aeos::Blake512.digest(bytes)` and `.hexdigest(bytes)`; neither is available in
this phase.

The planned implementation wraps the designer's C reference. It will not use
Rails, OpenSSL, FFI, Primus, BLAKE2, or BLAKE3 as a hashing fallback.

## Local development

The initial target is MRI 2.7.4 on macOS arm64. Other Ruby/platform combinations
have not been validated. With that Ruby selected and the development gems
installed, run `bundle exec rake spec`. To check the current package, run
`gem build blake512-ruby.gemspec` and inspect the built gem's file list.
The package currently supplies the Ruby loader, version, type signature,
pinned reference source, notices, and documentation. Installing it does not
enable hashing. See `VECTORS.md` for the independently checked fixture set.

## Native build layout

The pinned upstream C source, header, and CC0 notice are preserved under
`ext/aeos_blake512/upstream/`; see `UPSTREAM.md` for provenance and hashes.
Later phases will add the Ruby binding and an `extconf.rb`. The compiled library
will load privately beneath `aeos/blake512/`. The gemspec will register that extension only when those
files and a working build exist. There is no native build or runtime fallback
in this skeleton.

The gemspec lists each packaged file explicitly, including the upstream source,
header, and license. Build outputs must stay excluded. A later phase will verify
clean-checkout compilation and an isolated installed-gem smoke check before this
gem is described as usable for hashing.

## License

The current gem skeleton retains the repository's existing MIT license.
The imported upstream C reference retains its separate CC0 notice.
