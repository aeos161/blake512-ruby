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
`lib/aeos/blake512/`. Run `bundle exec rake spec` for the 54 examples;
that task also rebuilds the library. The native library is required when the
gem is loaded. Loading does not compile or download anything.

The source gem registers `ext/aeos_blake512/extconf.rb` for native compilation
at installation. An isolated installed-gem build and broader platform matrix
are Phase 4 validation gates; this checkout result alone does not establish
them. `UPSTREAM.md` records the unmodified CC0 source and reviewed build
adaptation; `VECTORS.md` records independent digest evidence.

## License

The Ruby binding retains the repository's MIT license. The imported upstream
C reference retains its separate CC0 notice.
