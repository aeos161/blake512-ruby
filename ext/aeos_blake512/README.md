# Native extension layout

`upstream/` remains a byte-identical snapshot with the original CC0 notice;
`UPSTREAM.md` gives its revision and checksums. `blake512_core.h` and
`blake512_core.inc` are the Phase 3 build adaptation. The latter is included
by `blake512_native.c`, so the extension has one C translation unit. The
adaptation omits the upstream CLI and self-tests, marks internal functions and
tables `static`, and otherwise retains the reference compression, counter,
and padding logic. See `UPSTREAM.md` for the exact patch inventory.

`extconf.rb` registers the private `aeos/blake512/blake512_native` load target.
The checkout `rake compile` task builds and copies it beneath `lib/`.
