# Phase 4 — Reliable builds and installed-gem identity

## Goal

Make the completed BLAKE-512 byte API reliably buildable and installable from a
source gem, with a small read-only identity descriptor and explicit rejection
of stale source/native combinations. Prove a clean installed gem works outside
the checkout; do not promise byte-for-byte identical compiler output.

## Baseline and reconciliation

Inspected clean gem `main` at `4981621` (Implement the native BLAKE-512 byte
API), also the locally recorded origin/main. No remote fetch was performed.
The original six-phase roadmap remains in the Primus repository at
`docs/plans/standalone-blake512-gem.md`; this document is the actionable Phase 4
handoff and lives with the gem. No cross-repository edit is needed.

Already implemented: `Aeos::Blake512.digest` and `.hexdigest`, namespaced
`aeos/blake512/blake512_native` loader, mkmf extconf, extension registration,
explicit gem file list, pristine upstream snapshot and reviewed private C
adaptation. `rake compile` runs extconf, make clean and make, then copies the
library into lib; `rake spec` recompiles. RBS declares the two methods. There
is no build descriptor, stale-source check or explicit checkout clean task.
The gemspec summary still describes a skeleton.

Phase 3 records 54 passing examples on MRI 2.7.4/macOS arm64 and a built source
gem. Those results were not rerun while planning. Isolated installed-gem
operation remains unverified. The existing tests group VERSION and methods
under one outer `RSpec.describe Aeos::Blake512`; retain that convention.
No prerequisite refactor is indicated. Preserve the hash core and its fixtures.

## Acceptance criteria

- A clean checkout compile and isolated source-gem installation both produce
  the existing known answers on MRI 2.7.4/macOS arm64.
- `require "aeos/blake512"` performs no writes, compilation, downloads or Git
  calls; it validates local source/native identity before returning success.
- `.build_info` returns a recursively frozen Hash with the schema below;
  callers cannot modify nested Strings or hashes. Repeated access describes
  the same successfully loaded artifact, not a new lookup of installed gems.
- Editing a declared source input, changing the input manifest, changing the
  Ruby version file, or replacing the native artifact with an older build
  causes fresh-process loading to fail. A clean rebuild restores loading.
- A missing declared source or malformed/unsupported identity is an explicit
  load failure. There is no compatibility fallback or automatic repair.
- A source gem includes all build/identity inputs and notices, excludes compiled
  libraries/objects/generated build metadata, and installs without Git/network
  source retrieval. Required compilation failure fails installation.
- Cleaning removes only known generated checkout outputs. A failed rebuild
  cannot leave a previously copied library appearing to be the new result.
- Missing/unloadable native code preserves LoadError semantics. Custom stale
  identity failures use `Aeos::Blake512::BuildMismatch < LoadError`. Unrelated
  programming errors are not broadly rescued or translated.

## Approach

### Increment A — Define and embed the minimal identity

Use the existing one-translation-unit extension. Add one packaged, versioned
source-input manifest and one small Ruby build-identity helper used by extconf
and loader; no generic registry, build service or extra runtime gem dependency.
Use standard-library SHA-256 and JSON. A generated C header embeds the build
identity as data; do not interpret arbitrary generated Ruby code at runtime.
Expose it through a private native accessor, leaving digest behavior unchanged.

The checked-in manifest is a sorted list of relative regular-file paths under
the gem root. Initial membership: loader, version file, identity helper,
extconf, native binding, core .h/.inc and pristine upstream blake.h/blake512.c.
Any new executable helper needed by those paths must be added. Include the
manifest's own bytes in the source digest using a separate fixed entry to
avoid a recursive hash. Embed the canonical path list as well as digest;
compare embedded membership with current membership so removing an input
cannot hide an edit. Reject duplicate, absolute, traversal or escaping symlink
paths and missing/non-regular files; never follow paths outside the gem root.

Compute one deterministic SHA-256 over sorted relative paths and file bytes
using unambiguous length-prefixed framing; document framing/version in helper
comments and pin a small independently calculated fixture for it. Do not hash
absolute paths, mtimes, generated headers, Makefiles, objects, library output,
logs, Git data, specs, README, Rakefile or other development-only files. These
are either unstable, circular or unavailable in the installed source package.
Rakefile changes alone therefore require normal review/rebuild discipline;
they are not claimed as runtime source checks. License/provenance documents
remain explicitly packaged and checked by package tests, not executable identity.

Record compiler/configuration separately after extconf has resolved build
settings. Capture Ruby engine, Ruby API version, platform, DLEXT, compiler
command and effective compile/preprocessor/link flags used by the generated
Makefile. Define support around the documented extconf configuration path;
manual make-time overrides require rerunning configuration and are outside
the trustworthy descriptor contract. Build metadata is provenance, not a
hermetic reconstruction of every system header, linker input or environment.

Deliverable: shared identity computation, manifest, generated-header support,
private native descriptor and RBS/public descriptor contract. Generated
artifacts stay ignored and are created only by explicit build/install steps.

### Descriptor contract

Return a deeply frozen Hash with String keys; no timestamps or Git dependency.
Do not include availability: successful require means this build loaded;
Primus will model unavailable attempts later.

| Field | Type and meaning | Consumer use |
| --- | --- | --- |
| schema_version | Integer, initially 1 | Descriptor compatibility |
| algorithm | String, `blake512` | Stable identity |
| gem_version | String, matches loaded VERSION | Stable identity |
| upstream_revision | String, pinned full revision | Stable provenance |
| source_sha256 | 64 lowercase hex String | Stable declared-source identity |
| native_sha256 | 64 lowercase hex String | Exact loaded-artifact identity |
| ruby_engine | String, `ruby` | Build compatibility context |
| ruby_api_version | String from build RbConfig | Build compatibility context |
| ruby_platform | String from build configuration | Build compatibility context |
| dlext | String from build configuration | Build compatibility context |
| compiler | String, configured command | Diagnostic provenance |
| compile_flags | Hash of String keys/values for recorded effective flags | Diagnostic provenance |
| native_path | Absolute String path of actually loaded file | Diagnostic only |

The internal embedded descriptor additionally carries the manifest membership;
no public per-file registry is needed. Source/native/version and compatibility
fields can feed a later consumer fingerprint. Absolute native paths and
compiler commands containing local paths must not accidentally make a
portable fingerprint machine-specific. Different binary bytes intentionally
produce different native_sha256, even from the same source. Public metadata
must describe the loaded build, never a different gem found by name.

### Increment B — Validate loading and make rebuilds safe

Retain the current public require path. Define BuildMismatch before loading
native code; allow normal native LoadError to propagate for absent or
incompatible artifacts. Once loaded, identify the single exact namespaced
native feature in loaded features, not an arbitrary suffix/glob or the first
gem of this name. Fail if that association cannot be established unambiguously.
Compare embedded schema, version, input list/digest and Ruby API compatibility
with current source/runtime, then construct and deeply freeze build_info using
the actual library's SHA-256. Do not require patch-version equality where the
Ruby API is unchanged; the platform loader remains responsible for binary
architecture compatibility. Report mismatch with useful rebuild guidance;
tests assert the exception class, not English wording.

Validation happens once per fresh process/load. It is not tamper protection,
live file monitoring or a guarantee against concurrent replacement during
loading. After successful load, the descriptor is a snapshot; later disk edits
require a new process to validate. Document that boundary explicitly. Do not
add a hot reload system or rehash sources on each digest call. BuildMismatch
aborts normal require usage; no promise is made to undo native initialization
side effects after a failed require in the same process.

Extend compile rather than replacing it. Remove the old copied library before
starting a rebuild; copy the newly built artifact only after success, preferably
through a temporary sibling and rename. Add a targeted clean task covering
known generated Makefile/log/header/object/extension outputs and the copied
lib artifact. Anchor cleanup paths to the repository root, not caller cwd;
never recursively delete source directories or user-supplied paths. Include
platform DLEXT outputs and temporary copied output. No broad filesystem cleaner.
Do not remove a currently installed gem or alter user's global gem settings.

Deliverable: guarded loader, clear errors, immutable metadata, safe clean and
rebuild tasks; stale-source verification uses subprocesses because ordinary
require caching can otherwise conceal the condition.

### Increment C — Prove source packaging and isolated installation

Update the explicit gemspec inventory for new helper/manifest files and fix
its skeleton summary. Generated identity headers/binaries are excluded from
the source gem and regenerated by extconf at install. Runtime identity inputs
must be present at stable relative paths in both checkout and installed gem.
Keep upstream notices and existing source adaptation intact; do not add Git
file discovery or fetch-time source dependencies.

Build the source gem and inspect its actual archive contents. Install that
artifact into a disposable GEM_HOME/GEM_PATH using the selected Ruby, then
start a fresh Ruby outside the checkout. Clear Bundler/RUBYOPT/RUBYLIB and
checkout load-path influence in the child environment without modifying parent
settings. Use a temporary working directory, no Git checkout and no network
source retrieval. Assert the selected gem/version and native path belong to
the disposable install; verify literal abc and binary known answers through
the public API and its descriptor. Repeat from a clean build, not just the
existing ignored development bundle. Preserve useful build diagnostics on
failure and clean only test-owned temporary directories.

In isolated build fixtures, exercise unavailable compiler and missing/unloadable
library. Do not uninstall a real compiler or manufacture a platform claim from
one macOS test. A failed build must exit unsuccessfully, while missing native
code raises LoadError; no successful source-gem installation may silently
omit its extension. Simulated load failures and an unavailable compiler fixture
are sufficient here; actual cross-architecture validation belongs to Phase 5.

Deliverable/stopping point: checked-in focused tests and README/ext README/RBS
updates, recorded clean-build and isolated-install commands/results with exact
Ruby/platform/compiler context. Stop for user review before Phase 5.

## Test-writer handoff

Implementation has not started. After user review, write focused failures for
new behavior, leaving the 54 Phase 3 examples as regression coverage. Keep one
outer describe for Aeos::Blake512 with method groups (including VERSION).
Place namespaced helper specs under `spec/lib/aeos/blake512/`; build/install
scenarios can live under `spec/integration/` with explicit subprocess entrypoints.
One behavior/expectation per example, no let/let!, tuples of unrelated assertions,
deep Demeter chains or exact error-message coupling. Five-line methods remain
a readability heuristic, not a reason for artificial abstractions.

Prioritize these independent scenarios:

- Descriptor reports expected source/algorithm/version values; nested mutation
  fails; native digest matches the actual loaded library file.
- An unchanged build loads after moving the whole checkout/install to a new
  path; metadata path changes but source identity does not.
- Source edit, manifest membership edit, version edit, deleted input and older
  binary each fail in a fresh process; documentation-only edits do not.
- Clean rebuild after a source edit restores successful loading and known
  answers. Source edits should be harmless comments, not algorithm corruption.
- Require works with a read-only source tree and no compiler/Git/network;
  build_info and hashing introduce no output files.
- Clean preserves all tracked inputs; failed rebuild leaves no copied success
  artifact. Run destructive fixture operations only in disposable copies.
- The built archive contains required source/manifest/notices and excludes
  generated outputs; isolated install resolves its own library and hashes a
  literal known answer. Separate examples check missing compiler/load failures.

Reuse a small number of clearly named disposable build fixtures to avoid
rebuilding for every metadata assertion. Keep observable outcomes rather than
mocking every mkmf/internal helper step. Run focused specs, all digest regressions
and the isolated package smoke once changes settle; broaden only for failures
or new risks. Do not report earlier results as a fresh run.

## Edge cases, limits and open decisions

A wrong binary may fail before the custom verifier executes; native LoadError
is correct. Libraries that load but lack the private identity accessor must
fail as BuildMismatch, not an unrelated NoMethodError. Detect source membership
changes with embedded data, but do not claim security against malicious code
that rewrites the verifier. Reading packaged sources once is intentional and
small; read permission is required. No writes occur during require.

Proposed defaults above resolve routine design choices; no user decision blocks
planning. The public addition is `.build_info` plus BuildMismatch. Review that
small API contract before implementation. If packaged installation exposes a
RubyGems path-layout difference, resolve it locally without a general discovery
framework and retain the same observable acceptance criteria.

## Out of scope

No crypto-core changes, new digest API, streaming, GVL changes, generic build
framework, public release, binary gems, CI expansion, sanitizers, wider Ruby/
platform support or Primus integration. Phase 5 owns broader validation; Phase 6
owns unavailable-backend translation and experiment fingerprints. No code,
tests or test-writer handoff is performed by this planning change. WIP planning
commit only; no push or publication.
