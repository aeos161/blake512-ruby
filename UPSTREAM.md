# Original BLAKE-512 source provenance

The source snapshot in `ext/aeos_blake512/upstream/` comes from the BLAKE
reference repository maintained by designer Jean-Philippe Aumasson. It is the
final original BLAKE-512 (16 rounds), rather than the initial BLAKE-64 or
BLAKE2/BLAKE3. The selected immutable Git commit is
`65f9ac8101191b12368e533afed6486c5b694fa3`:

- Repository: https://github.com/veorq/BLAKE
- Commit: https://github.com/veorq/BLAKE/tree/65f9ac8101191b12368e533afed6486c5b694fa3
- Raw files: `https://raw.githubusercontent.com/veorq/BLAKE/65f9ac8101191b12368e533afed6486c5b694fa3/<name>`
- Designer's final algorithm page: https://www.aumasson.jp/blake/

| Original file | SHA-256 | Local copy |
| --- | --- | --- |
| `blake.h` | `1a2011a191e48c23df9d21405c15faf22a8b00171b665e040066093c34114448` | `upstream/blake.h` |
| `blake512.c` | `b0830b8be2509786dc00468c68b7a13ccecfbde3fa31e3cde5d106fe2dfef10a` | `upstream/blake512.c` |
| `LICENSE` | `5537d4d10b76b81b6e8dfd8b644480a4b1efa332fbb0cdb61126c5be781ef7b4` | `upstream/LICENSE` |
| `README.md` | `942d154e3ffd88cb2ae9473854984002826cb04f76c09a53a51081a1c879ff10` | `upstream/README.md` |

These are SHA-256 digests of the original Git blobs and byte-identical local
copies. Verify with `shasum -a 256 ext/aeos_blake512/upstream/*` and
`git show <revision>:<name> | shasum -a 256` in a checkout of the designer's
repository. The original source and README identify the code as CC0-1.0; its
full notice is preserved as `upstream/LICENSE`. The gem wrapper's existing
`LICENSE.txt` remains MIT. No local changes have been applied to the imported
files.

The upstream `blake512.c` includes its own two zero-input self-tests and a
file-hashing CLI `main`. These remain in the snapshot as evidence; they must
**not** be linked into the Ruby extension. Phase 3 should make a minimal,
reviewed copy or patch that excludes `blake512_test` and `main` from extension
builds while leaving compression, update and finalization unchanged. A
conditional compile guard around those CLI-only functions is sufficient.
The shared `blake.h` defines `sigma` and `u512` tables with external linkage,
so include it in only the reference translation unit, or split declarations
and definitions without duplicating them. The Ruby binding can forward-declare
only `blake512_hash` in a private header. Keep exported symbols private where
possible, and inspect them in the compiled extension.

`blake512_update` accepts a `uint64_t` byte length; its local buffer counters
are `int` but stay within a 128-byte block. Phase 3 must check conversion from
Ruby's signed String length, pointer lifetime and large one-shot calls before
using that entrypoint. No native Ruby build is registered in Phase 2.
