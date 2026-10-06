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
file-hashing CLI `main`. These remain untouched in the snapshot as evidence.
Phase 3 builds from a reviewed adaptation kept beside that snapshot:

| Build input | SHA-256 | Changes from pinned source |
| --- | --- | --- |
| `blake512_core.h` | `e0dd712a68e78a8058da4c10181c3a4690ce67db543869cb9d451aed1f55cfc6` | `blake.h` with only `sigma`, `u256`, and `u512` changed from `const` to `static const`. |
| `blake512_core.inc` | `c0ead701a59c734a2d172ce7667324ea9ea14776f189d381fc06110b1cf514be` | `blake512.c` with its include renamed, five `blake512_*` functions marked `static`, the CLI self-test plus `main` removed, and trailing blank lines trimmed. |

The reference compression, update, counter, and finalization bodies are
otherwise unchanged. `blake512_native.c` includes the `.inc` file, creating
one translation unit. No source table or function is exported from the
extension; on the tested build, `nm -gU` reports only
`Init_blake512_native`. Diff the adapted files against their `upstream/`
counterparts to review every change. The upstream `blake.h` defines tables,
so compiling it in more than one translation unit would create duplicate
symbols; this layout avoids that.

`blake512_update` accepts a `uint64_t` byte length. The binding checks that
input is a String (including subclasses), reads Ruby's signed `long` length,
rejects a negative or unrepresentable length, and passes that length without
narrowing to `int`. The upstream `int` buffer counters stay within a 128-byte
block as full blocks are consumed from the `uint64_t` length. The binding
holds the GVL and makes no Ruby calls while it uses the input pointer, then
copies 64 output bytes into a new Ruby String. A fresh stack state is used
for each call. Large one-shot calls hold the GVL; streaming and GVL release
remain out of scope.
