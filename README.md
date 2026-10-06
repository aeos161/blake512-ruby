# blake512-ruby

This MRI gem hashes exact String bytes with the final, 16-round original
BLAKE-512 algorithm. Require it with `require "aeos/blake512"` and use the
`Aeos::Blake512` namespace:

```ruby
binary = Aeos::Blake512.digest("abc")
hex = Aeos::Blake512.hexdigest("abc")
```

`digest` returns a fresh 64-byte binary String. `hexdigest` returns 128
lowercase ASCII hex characters. Both accept String subclasses and reject
other objects with `TypeError`; neither converts objects or text encodings.
The binding uses the pinned designer C reference. It has no Rails, OpenSSL,
FFI, Primus, BLAKE2, or BLAKE3 runtime dependency or fallback.

## Checkout build

The validated development target is MRI 2.7.4 on macOS arm64. Select that
Ruby, install the Gemfile's development dependencies, then run
`bundle exec rake compile` to build and copy the native library beneath
`lib/aeos/blake512/`. Run `bundle exec rake spec` for the regression
and build/installation examples; that task also rebuilds the library. `bundle exec rake clean` removes only
known generated checkout outputs. The native library is required when the
gem is loaded. Loading does not compile or download anything.

The source gem registers `ext/aeos_blake512/extconf.rb` for native compilation
at installation. It includes the declared source inputs and upstream notices,
while generated build files are excluded. A local source-gem build and isolated
installation were verified on MRI 2.7.4/macOS arm64 with clang. Broader Ruby
and platform testing remains future work. `UPSTREAM.md` records the unmodified
CC0 source and reviewed build adaptation; `VECTORS.md` records independent
digest evidence.

## Build identity

`Aeos::Blake512.build_info` returns a deeply frozen Hash with String keys:
`schema_version`, `algorithm`, `gem_version`, `upstream_revision`,
`source_sha256`, `native_sha256`, `ruby_engine`, `ruby_api_version`,
`ruby_platform`, `dlext`, `compiler`, `compile_flags`, and `native_path`.
The SHA-256 fields identify the declared source inputs and the native file
that was loaded. Compiler settings and the absolute native path are diagnostic;
paths should not be used as portable fingerprints.

A fresh `require "aeos/blake512"` compares the embedded build identity with
packaged source files, their manifest, the gem version, and the running Ruby
API. Stale or malformed identity raises `Aeos::Blake512::BuildMismatch`, a
subclass of `LoadError`; missing or unloadable native code raises `LoadError`.
Rebuild or reinstall the gem after changing declared source files. Loading does
not compile, download, consult Git, or write files. The descriptor is a snapshot
of a successful load: later disk changes are checked only by a new process.
This is an accidental-mismatch check, not tamper protection or a promise of
byte-identical compiler output. The declared inputs exclude Rakefile, docs,
headers outside the gem, and build-tool internals.

## License

The Ruby binding retains the repository's MIT license. The imported upstream
C reference retains its separate CC0 notice.
