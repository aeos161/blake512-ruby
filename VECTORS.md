# Phase 2 BLAKE-512 fixture evidence

`spec/fixtures/blake512_vectors.json` contains 13 literal, lowercase,
128-character digests for final original BLAKE-512 with zero salt and no key.
Each entry names its exact bytes or a deterministic byte construction:

- `hex`: those exact hexadecimal bytes, including the empty string.
- `repeat_hex` and `length`: repeat the named byte exactly that many times.
- `sequence_mod_256`: for index `i` from zero, byte `i mod 256`, for the
  stated length. This supplies binary input with NUL and high bytes across
  multiple 128-byte blocks.

The two `designer-self-test` values are literal answers embedded in the
pinned designer `blake512.c`: one `0x00` byte and 144 `0x00` bytes. The
`noble-test-literal` empty answer is present in the independent backend's
`test/blake.test.js`. `abc` and the boundary/binary cases are
`oracle-derived`: produced by that separately implemented backend, then
cross-checked against the designer's C CLI. These are **not** claimed as
published designer vectors. The 110/111/112-byte cases straddle the special
111-byte finalization branch; 127/128/129 straddle a 128-byte block boundary.

Independent oracle: `@noble/hashes` BLAKE1 `blake512`, release 1.8.0,
Git commit `32f700f38ec49d7e6b2ab687904d6b2d7d60d80a`:

- Source: https://github.com/paulmillr/noble-hashes/tree/32f700f38ec49d7e6b2ab687904d6b2d7d60d80a
- Published package: https://www.npmjs.com/package/@noble/hashes/v/1.8.0
- Downloaded `noble-hashes-1.8.0.tgz` SHA-256:
  `e8a765d92c04faaccba8776411c5038cb195f812ee629fce07e1d2e6aec80ea0`
- Package `src/blake1.ts` SHA-256:
  `bc232796e5e0811d81d96b120c41ef7166f9df2f5d5af516075be31571f6f586`
  (byte-identical to that file at the Git commit).

To repeat the cross-check, use Node.js 18 or newer and a C99 compiler.
Outside this gem repository, run `npm pack @noble/hashes@1.8.0`, verify the
tarball SHA-256 above, and extract it with `tar -xzf noble-hashes-1.8.0.tgz`.
Then from this repository run
`node research/verify_vectors.js /absolute/path/to/package`. The verifier
checks source SHA-256 values, compiles the untouched C CLI in a temporary
directory, and compares every literal answer with both implementations.
It needs no network once the oracle package has been obtained. The npm package
and JavaScript are research tools, not gem dependencies.

The designer C CLI and a Ruby binding around the same C are not independent
algorithm oracles. The noble-hashes code is a separate TypeScript
implementation. Its 16-round compression loop and zero-salt default were
reviewed at the pinned source revision. Together with the designer self-tests,
the cross-check establishes independent agreement for these cases. No Ruby digest behavior exists yet;
Phase 3's test-writer can use these literal fixtures for red API examples.
