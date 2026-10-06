# Native extension layout

`upstream/` remains a byte-identical snapshot with the original CC0 notice;
`UPSTREAM.md` gives its revision and checksums. `blake512_core.h` and
`blake512_core.inc` are the Phase 3 build adaptation. The latter is included
by `blake512_native.c`, so the extension has one C translation unit. The
adaptation omits the upstream CLI and self-tests, marks internal functions and
tables `static`, and otherwise retains the reference compression, counter,
and padding logic. See `UPSTREAM.md` for the exact patch inventory.

`extconf.rb` registers the private `aeos/blake512/blake512_native` load target.
`extconf.rb` also reads the versioned `source_inputs.json` manifest and
embeds the source digest, membership, Ruby build configuration, compiler, and
flags in a generated header. That header is recreated for every configuration
and is absent from the source gem. The checkout `rake compile` task removes any
old copied library before configuring and building, then copies the new library
beneath `lib/`. `rake clean` removes only known generated files.
