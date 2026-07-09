# SHA-256 object format — scoping / design pass (now implemented)

Status: **implemented** (all phases below ✅). SHA-256
(`extensions.objectFormat = sha256`) repositories are read and written and match the system
`git` on-disk format; the format is accepted (not rejected) by
`Version.Repository_Format.Finalize_Compatibility`, `init --object-format=sha256` creates
them, and interop is verified end-to-end (local + smart HTTP/SSH, both directions) against
system git. This document is retained as the design record and phase log that led there;
the per-phase "✅ Done" notes are the authoritative account of what shipped.

> Note: the "Deliberately still gated" caveat under Phase 2 below was superseded by Phase 4
> (the gate was lifted); it is left in place as the historical phase narrative.

## Goal

Read and write repositories whose object format is SHA-256, matching the system `git`
on-disk format (64-hex / 32-raw-byte object ids, pack index v3, SHA-256 pack/index/commit
trailers), so that `git --object-format=sha256` repositories are byte-compatible. A
repository is a single format for its lifetime — SHA-1 and SHA-256 are never mixed — which
is the key simplification: the id width is fixed **per repository**, chosen at `init`/`clone`.

## Current SHA-1 coupling (evidence)

| Area | Coupling | Key sites |
|---|---|---|
| **Object id type** | `subtype Hex_Object_Id is String (1 .. 40)` — a *definite constrained subtype* | `version-objects.ads:10` |
| — used in records | `Tree_Entry.Id`, `Staging.Index_Entry.Id` (definite components) | `version-objects.ads:26`, `version-staging.ads:13` |
| — used in containers | `Object_Id_Vectors` (definite element) | `version-objects.ads:35` |
| — validation / slicing | `Value'Length /= 40`, path slice `Id (3 .. 40)` | `version-objects.adb:27,48`; `version-write.adb:114` |
| **Hashing** | SHA-1 only: `Sha1_Hex` (40), `Sha1_Raw` (20); object hash of `"<kind> <size>\0<content>"` | `version-hash.ads`; `version-write.adb:84-93` (`Object_Id_For`) |
| **Tree binary ids** | fixed 20-byte parse/write per entry | `version-objects.adb:462,492,497,600`; `version-write.adb:385,407` |
| **Pack** | 20-byte trailer, SHA-1 context, 20-byte raw ids | `version-pack.adb:225`; `version-pack_write.adb:261,312` |
| **Pack index** | idx v2; `Pack_Checksum'Length /= 20` rejected; 20-byte raw ids + SHA-1 index checksum | `version-pack_index.adb:97-99,122,146` |
| **Staging index** | 20-byte raw id on disk (`Hex_To_Raw`/`Raw_Id_To_Hex`) | `version-staging.adb:121-146,399-429` |
| **Refs** | 40-hex text (external Git format) | `version-refs.ads` |
| **Format config** | `Object_Format` parsed into `Format_Info` but only checked at the compat boundary; **not** threaded to object I/O | `version-repository_format.ads:12`, `.adb:229,259-261` |

`Hex_Object_Id` is referenced across ~110 source files. `Version.Hash` = one file. The
format value exists but never reaches `Read_Object`/`Write_Loose_Object`/`Object_Id_For`.

(LFS's `GNAT.SHA256` use in `version-lfs.adb` is content addressing, unrelated to object format.)

## The central design decision: the id type

`Hex_Object_Id = String (1 .. 40)` is *definite*, which is exactly why it drops into records
and `Vectors` without discriminants. Supporting 64-hex ids requires one of:

- **Option A — variable-length string.** `subtype Hex_Object_Id is String;` (unconstrained).
  Cleanest semantics (concatenation, slicing, `=` all keep working), but the subtype becomes
  *indefinite*, which cascades:
  - record components (`Tree_Entry.Id`, `Index_Entry.Id`) must become `Unbounded_String`
    (or discriminated records);
  - `Object_Id_Vectors` must become `Indefinite_Vectors`;
  - every fixed-40 literal/slice (`Id (3 .. 40)`, `'Length = 40`) must be audited.
  Churn is concentrated in ~a dozen type/container definitions plus a literal audit.

- **Option B — bounded private type.** `type Hex_Object_Id is private;` wrapping a
  `String (1 .. 64)` + length. Stays *definite* (records/containers structurally unchanged),
  but every use site (`String (Id)`, `Id (3 .. 40)`, `Id = Other`, `& Id`) must go through
  accessors / overloaded `"="`, `"&"`, `Image`, `Slice`. Churn is spread across all ~110
  files but is mechanical.

**Recommendation: Option B (revised after measurement).** Option A was tried end-to-end and
**rejected on performance**: making `Hex_Object_Id` an unconstrained `String` compiles and
passes the full suite, but regresses it from **~114 s to >500 s (>5×)**. The cause is
fundamental, not incidental — an unconstrained `String` *return* type forces secondary-stack
allocation on every id-returning call, and ids are returned on the hottest paths (object id
computation, ref resolution, tree parse). Widening record fields to `Unbounded_String` and
containers to `Indefinite_*` compounds it (heap indirection per element in the object cache,
hit on every read). So the "cleanest semantics" of Option A come at an unacceptable hot-path
cost for the SHA-1 case that must stay fast.

Option B (a **definite** bounded type — `String (1 .. 64)` + length, or `Ada.Strings.Bounded`
with max 64) avoids all of this: definite means no secondary stack, no heap-per-element, and
records/containers stay by-value. Its cost is per-use-site accessor churn, which is mechanical
and — crucially — does **not** regress performance. That is the correct trade for a
performance-sensitive VCS.

**What Phase 1 actually landed (behavior-neutral prep):** every id *storage* site (record
fields, id containers, fixed arrays, uninitialized locals) was routed through a single new
`subtype Object_Id_Storage is String (1 .. 40)` in `Version.Objects`, distinct from
`Hex_Object_Id` (which stays `String (1 .. 40)` for now — the value/API form). This is the
anchor point for Option B: `Object_Id_Storage` becomes the definite bounded type; the storage
sites already point at it. Full suite stays green (1102) and fast (114 s). No behavior change.

Either way, `Is_Valid_Hex_Object_Id` accepts length 40 **or** 64 (validated against the
repo's format, not unconditionally).

## Hash + format threading

1. **`Version.Hash`**: add a real SHA-256 (Sha256_Hex/Raw + streaming context), and a
   descriptor `type Hash_Algorithm is (Sha1, Sha256)` with `Hex_Length` (40/64) and
   `Raw_Length` (20/32).
2. **Reaching object I/O**: `Repository_Handle` already threads through nearly every
   object operation. Read `objectFormat` once at `Repository.Open` and store the
   `Hash_Algorithm` on the handle; object I/O derives the algorithm from `Repo` rather than
   gaining new parameters. This avoids a second 110-file signature churn.
   - `Object_Id_For (Repo, kind, content)` selects the hash by `Repo`'s algorithm.
   - Tree parse/write, staging `Hex_To_Raw`/`Raw_Id_To_Hex`, loose-object path slicing use
     `Raw_Length`/`Hex_Length` from `Repo` instead of literals.

## Format-version bumps

- **Pack index**: SHA-256 packs use **idx v3** (32-byte object ids + 32-byte trailer/pack
  checksum). Add v3 write + read; the `/= 20` guard becomes `/= Raw_Length`.
- **Pack trailer**: 32-byte SHA-256 checksum; `Pack_Size - 20` → `- Raw_Length`.
- **Loose objects / trees / commits**: no in-file format marker — governed by the repo-wide
  `objectFormat`. Commit/tag object text also embeds 64-hex parent/tree ids (handled by the
  id-type change, but any 40-based parsing of commit headers must be audited).
- **Staging index**: git ties the index hash to the repo format; raw id width 32, and the
  index trailer hash follows the repo algorithm.

## Phased plan

- **Phase 0 — Hash abstraction. ✅ Done.** `Version.Hash` now has SHA-256
  (`Sha256_Hex`/`Sha256_Raw` + streaming `Sha256_Context`) and the `Hash_Algorithm`
  descriptor (`Hex_Length`/`Raw_Length`), verified against FIPS 180-4 vectors. No
  object-format behavior change yet — the remaining phases wire it in.
- **Phase 1 — Id storage isolation. ✅ Done (prep); Option A rejected on perf.** All id
  *storage* sites now route through `Object_Id_Storage` (definite `String (1 .. 40)`), the
  single anchor to widen later. Option A (unconstrained `String`) was implemented and reverted
  after it regressed the suite >5× (see the Recommendation section above). An **accessor seam**
  is now in place — `Version.Objects.To_String (Id)` and `To_Object_Id (Text)` (identities
  today) — the single point through which every id⇄text access will route.

- **Phase 1b — Bounded-type migration. ✅ Done.** `Object_Id_Storage` is now a definite
  record (`Length : 0 .. 64` + `Text : String (1 .. 64)`, unused bytes kept canonical so the
  predefined `"="` is correct); `Hex_Object_Id` is a subtype of it. The seam (`To_String`,
  `To_Object_Id`, `Zero_Object_Id`, `Id_Length`, `"<"`, and `"=" (id, String)` overloads) is
  the sole access path. All use sites across **every crate** were migrated — versionlib
  (source + tests), the CLI (`version-cli.adb`), the CLI tests, and `tools/`: `String (id)` →
  `To_String (id)`, `Hex_Object_Id (text)` → `To_Object_Id (text)`, hex literals →
  `To_Object_Id`/`Zero_Object_Id`, id slices → `To_String (id) (…)`, and container
  instantiations carry an explicit/`use type`-visible `"<"`.

  **Result: definite means fast.** Full suite **1102/1102 in 116 s** — statistically identical
  to the pre-flip 114 s, confirming the bounded record has **no** secondary-stack/heap cost
  (contrast Option A's >500 s). CLI 114/114; both release gates green; zero warnings. The id
  type can now physically hold a 64-char SHA-256 id; what remains is threading the algorithm
  (Phase 2) and the format/pack-index work (Phases 3–5) so those 64-char ids are actually
  produced and parsed.

  **Measured blast radius** (from actually flipping the subtype to unconstrained and
  building): **49 compiler errors across 19 files**, all *definiteness* diagnostics in three
  mechanical categories — no logic errors:
  1. **Record components** `Id : Hex_Object_Id` (→ `Unbounded_String`): `version-objects.ads`
     (`Tree_Entry`), `version-staging.ads` (`Index_Entry`), `version-blame.ads`,
     `version-packed_refs.ads`, `version-pack_index.ads`, `version-submodules.ads`,
     `version-working_tree.ads`, `version-ref_transaction.ads`, and record fields inside
     `version-diff.adb`, `version-pack.adb`, `version-maintenance.adb`.
  2. **Container instantiations** (Element/Key = `Hex_Object_Id`, → `Indefinite_*`):
     `Object_Id_Vectors` (`version-objects.ads`), `version-history.ads`, and the id-keyed
     caches `version-object_cache.ads`, `version-pack_index_cache.ads`, `version-tree_cache.ads`,
     `version-maintenance.adb`.
  3. **Aggregates / array bounds** (`(others => …)` over ids, local arrays):
     `version-archive.adb`, `version-blame.adb`, `version-objects.adb`, `version-pack.adb`,
     `version-refs.adb`, `version-diff.adb`.

  The 19 files are only the *definiteness* front; changing record components to
  `Unbounded_String` then cascades a `To_String`/`To_Unbounded_String` edit to every `.Id`
  read/construct site (notably `Tree_Entry.Id` and `Index_Entry.Id`, used across dozens more
  files). Net realistic footprint: **~25–40 files**, mechanical but wide, and the SHA-1 test
  suite (1100+ tests) must stay green at every step. Best done as a dedicated, uninterrupted
  push in a git-backed working copy (this source tree is not itself a git repo, so mid-refactor
  states are hard to unwind).
- **Phase 2 — Thread the algorithm. ✅ Done (loose-object path); format still gated.**
  `Repository_Handle` now carries `Algorithm` (read from `extensions.objectFormat` at
  `Open`, exposed as `Version.Repository.Algorithm (Repo)`), and `Version.Hash` gained
  `Object_Hash_Hex/Raw (Algorithm, Input)` dispatch. `Version.Write.Object_Id_For` now
  takes `Repo` and hashes with the repo's algorithm; the loose-object path is
  length-agnostic (`To_String (Id) (3 .. 'Last)`), and `Read_Loose_Object`'s
  hash-mismatch check uses the repo algorithm. **All behavior-neutral today** — every repo
  is `sha1`, so `Object_Hash_Hex (Sha1, …)` reproduces the old output exactly (1103/1103,
  116 s). Verified the sha256 side against real git: `Object_Hash_Hex (Sha256,
  "blob 5\0hello") = 8aec4e48…`, git's actual sha256 blob id (unit test in
  `version-hash-tests`).

  **Deliberately still gated:** `extensions.objectFormat = sha256` remains rejected at
  `Require_Compatible`. This preserves the **reject-before-mutation safety contract** (a
  release-freeze property, enforced by `version-repository_format-tests`): staging/index,
  save/refs, restore, and fetch are *not* yet SHA-256-aware, so a sha256 repo must fail
  safely rather than be corrupted. Lifting the gate is Phase 4, and must not precede the
  work below.
- **Phase 3 — Pack + index v3, and SHA-256-aware mutating commands.** SHA-256 pack trailer +
  idx v3 read/write; make the staging index (32-byte raw ids + index trailer hash), tree
  parse/write, and ref/reflog paths derive their widths from `Repo`'s
  `Raw_Length`/`Hex_Length`. These are the commands currently gated by the safety contract.
  - **Tree parse — ✅ done.** `Version.Objects.To_Hex` accepts 20- or 32-byte raw ids;
    the single-level parser is now a pure `Parse_Tree (Algorithm, Data)` (both `Tree_Entries`
    and the recursive `Append_Flattened_Tree` derive `Raw_Length` from `Repo`).
  - **Tree write — ✅ done.** Added public `Version.Objects.To_Raw` (length-agnostic
    hex→raw: 40-hex→20 bytes, 64-hex→32 bytes), replacing `version-write.adb`'s hardcoded-20
    local `Raw_Id`; `Write_Tree_For_Prefix` now emits raw ids of the id's own width. Because
    a sha256 repo's blob/subtree ids are already 64-hex (Phase 2), the encoded tree carries
    32-byte raw ids with no further change. Unit-tested: `To_Raw` for both widths + a
    `To_Raw`→`Parse_Tree` sha256 round-trip (`version-objects-tests`).
  - **Id validation + object addressing — ✅ done.** `Is_Valid_Hex_Object_Id` accepts
    40- or 64-hex (unit-tested); the loose-object read path (`Version.Objects`
    `Loose_Object_Path`) and the three replay-op copies (revert/cherry_pick/rebase) slice
    `3 .. 'Last` instead of `3 .. 40`; `Version.Packed_Refs`' id check defers to the
    validator; and the full-id / abbreviation length checks (`Version.Revisions`,
    `Version.Am`, `Version.Rebase`) accept 40 or 64. All behavior-neutral for sha1
    (1106/1106).
  - **Staging index — ✅ done.** `Version.Staging` now derives `Raw_Length` from
    `Repo`'s algorithm and threads it through the reader: `Raw_Id_To_Hex` takes a width,
    `Scan_Index_Extensions`' trailer offset is `Data'Last - Raw_Length`, and every entry
    offset became `40 + RL`-relative (id at 40, flags at `40+RL`, name at `42+RL`, …).
    The writer emits the id via `Version.Objects.To_Raw` (replacing a duplicated hardcoded-20
    `Hex_To_Raw`) and computes the whole-file trailer with `Object_Hash_Hex (Algorithm, …)`.
    Behavior-neutral for sha1 — for `RL = 20` every offset reduces to the old literal, and
    all add/status/commit tests pass (1106/1106). Its components are unit-tested (`To_Raw`,
    `Object_Hash_Hex` dispatch); the full 32-byte index round-trip is a real-repo check
    deferred to Phase 5 interop (the index reader/writer are tied to `Repo` + file I/O).
  - **Pack index writer — ✅ done.** `Version.Pack_Index.Build` takes an `Algorithm`
    (default Sha1), emits 32-byte object names via `Version.Objects.To_Raw` (replacing a
    duplicated hardcoded-20 `Raw_Id`), validates the pack checksum against `Raw_Length`, and
    computes the idx trailer with `Object_Hash_Raw (Algorithm, …)`. `Version.Pack` and
    `Version.Pack_Write` pass the repo's algorithm. (git's sha256 idx is still v2, just
    wider — no separate on-disk "v3".) Unit-tested: a sha256 `.idx` has 32-byte names + both
    32-byte checksums, correct magic/version, and a sha256 trailer over the body.
  - **Pack index reader — ✅ done.** `Version.Pack_Index_Cache` threads `Raw_Length` (from an
    `Algorithm` param on `Load_Index`, defaulting to Sha1; `Load` and `maintenance` pass the
    repo's): `Id_At` reads a width-sized name, `Offset_For_Index`/`Load_Index` compute the
    name-table stride as `Object_Count * Raw_Length`, and the last entry's end offset is
    `Pack_Size - Raw_Length`. **Reader+writer now round-trip for sha256** — a Build-emitted
    32-byte `.idx` is loaded and `Locate` returns the right offset and `size - 32` end offset
    (unit-tested).
  - **Pack file reader — ✅ done.** `Version.Pack` threads `Raw_Length`/`Algorithm` (from
    `Repo`) through the whole read path: the inline `.idx` binary search (`Compare_Id_At`,
    `Offset_For_Index`, `Next_Offset_After`, `Index_Find_Location`, `Find_Location`), the
    ref-delta base-id reads (`Raw_Id_At`, `Read_Object_At_Location`, `Compressed_Data_Start`,
    `Index_Pack` — the `+20` base-name skips are now `+Raw_Length`), object-id hashing
    (`Object_Id_For` → `Object_Hash_Hex (Algorithm, …)`), and the whole-pack checksum
    (`Pack_Trailing_Checksum`, `Require_Valid_Pack_Checksum` → `Object_Hash_Raw`). Behavior-
    neutral for sha1 — every pack test passes (1108/1108). (sha256 pack-read verification is
    real-repo/interop, Phase 5, since packs arrive from remotes.)
  - **Pack writer — ✅ done.** Added `Version.Hash.Streaming_Context (Algorithm)` — a
    discriminated record dispatching Initialize/Update/Final_Raw to the inner Sha1/Sha256
    context (streams, never buffers the whole pack); unit-tested to match the one-shot digest
    for both algorithms. `Version.Pack_Write` uses it for the pack-file trailer and routes
    `Canonical_Object_Id` through `Object_Hash_Hex (Algorithm, …)`. Behavior-neutral (1109).
  - **Ref/reflog — ✅ no residual width** (hex-text; covered by `Is_Valid_Hex_Object_Id`
    + packed_refs).
  - **Duplicate consolidation — ✅ done (Phase 3 complete).** A full `Sha1_Hex`/`20`/`40`
    sweep had turned up duplicated object hashing / tree parsing that bypassed the shared
    primitives. Fixed by adding **`Version.Objects.Compute_Object_Id (Algorithm, Kind,
    Content)`** (the single place object ids are computed) and making **`Version.Objects.To_Hex`
    public** (length-agnostic 20/32-byte raw→hex), then routing every duplicate through them:
    - object-id computations — `Version.Revert`/`Cherry_Pick`/`Rebase`'s local `Object_Id_For`
      now take `Repo` and call `Compute_Object_Id`; `Version.Working_Tree`'s
      `Blob_Id_For_Content`/`Git_Blob_Id`/`Symlink_Blob_Id` take an `Algorithm` threaded from
      `Scan` → `Scan_Directory`.
    - tree parsers — `Version.History.Collect_Tree` and `Version.Reachability` now use
      `Version.Objects.To_Hex` + a `Raw_Length` derived from `Repo` (local `To_Hex` copies
      removed).
    Behavior-neutral for sha1 (1109/1109, CLI 114, both gates + doc-coherence green).
    *Intentionally left sha1* (internal cache keys, not git objects, so no interop impact):
    `Version.Merge` rerere key + merge-driver temp key, and `Version.Patch_Id` (an on-the-fly
    comparison hash, never stored) — verified by a final sweep to be the only `Sha1_Hex` uses
    left outside `Version.Hash`.
- **Phase 4 — Accept the format. ✅ DONE.** The `objectFormat /= "sha1"` rejection in
  `Version.Repository_Format.Finalize_Compatibility` now accepts `sha1` *and* `sha256` (any
  other format is still rejected). `Version.Init.Init`/`Init_Bare` take an
  `Object_Format : Hash_Algorithm := Sha1` argument and write git's exact sha256 config
  (`repositoryformatversion = 1` + `[extensions] objectformat = sha256`); the CLI exposes
  `version init --object-format=(sha1|sha256)`. The reject-before-mutation safety tests in
  `version-repository_format-tests` were removed (their contract is lifted); the former
  "sha256 rejected" test became `Sha256_Object_Format_Is_Compatible`, and the "bare config
  checked" / "does not mutate" tests now use `refStorage = reftable` for their still-
  unsupported case. The frozen `init` option surface (`version-cli-tests`) was extended for
  `--object-format`.
- **Phase 5 — Interop. ✅ DONE (local *and* smart HTTP/SSH transport).**
  Verified end-to-end against system git (2.43) in both directions. A `Sha1_Hex`/`20`/`40`
  sweep of the *reader/serialiser* paths (missed by the Phase-3 object-id sweep) fixed:
  commit/tag header id parsing (`Commit_Tree_Id`/`Commit_Parent_Ids`/`Tag_Target_Id` now
  parse the id to end-of-line and validate the width), reflog parsing (`Reachability`,
  `Stash` — split on spaces), packed-refs / merge-state / receive-pack / upload-pack / bundle
  ref-line parsing (first-space split), the local-transport loose-object filename check
  (accepts 62-hex sha256 names), `hash-object` (routes through the repo algorithm), clone
  (detects + reproduces the source object format), and the reflog null old-id
  (`Version.Reflog.Append` widens the 40-zero `Zero_Object_Id` to the repo's width, so git
  parses version's sha256 reflog). Confirmed with `git fsck --strict`, `verify-pack`,
  `bundle verify` (reports `sha256`), `reflog`, and local clone/push/fetch; and version reads
  git-created sha256 repos (log/status/ls-tree/show/cat-file/branch/tag).
- **Phase 5b — Smart HTTP/SSH transport. ✅ DONE.** SHA-256 is now negotiated over the smart
  transport: `Version.Upload_Pack.Advertised_Object_Format` reads the `object-format=sha256`
  capability from the ref advertisement; `Version.Fetch.Remote_Object_Format` performs a
  pre-init discovery so a clone target is created with the remote's format (all transports);
  the receive-pack client sends `object-format=sha256` in its push capabilities
  (`Push_Capabilities`) and uses a repo-width null id (`Null_Id`) for ref create/delete
  commands. Verified against a real `git http-backend` SHA-256 server: version clones,
  fetches, and pushes (update / branch create / branch delete), git `fsck`s the result, and a
  second `git clone` reads version's pushed commits. SSH uses the identical helpers (the
  advertisement read + `Push_Capabilities`/`Null_Id`), so it is covered by the same code path.
  Locked in by `Version.Sha256_Interop_Tests` (6 tests, incl. the capability parser).

## Risk hotspots

- **The id-type refactor (Phase 1)** — pervasive, must stay green continuously; the primary
  schedule risk. Recommend an aggressive grep for `40`/`20`/`Sha1` after the type change.
- **Mixed-format safety** — enforce one format per repo (already true; make it explicit at
  the I/O layer so a mis-thread can't silently produce a hybrid).
- **idx v3 correctness** — verify against git-produced sha256 packs, not just internal
  round-trip.
- **Commit/tag header ids** — 64-hex parent/tree lines; audit any 40-based header parsing.
- **Frozen contract** — object/pack/index formats are release-frozen; SHA-256 is a deliberate
  post-freeze extension and should be gated the same way as the SSH and partial-clone work.

## Effort

**Large — multi-session.** Phase 0 is small and self-contained. Phase 1 is the bulk (a
mechanical but wide type refactor across ~110 files). Phases 2–5 are medium each. Unlike the
transport work, SHA-256 is fully **verifiable locally** (system `git` produces sha256
fixtures with no server), which de-risks correctness once the plumbing lands.

## Recommendation

If pursued, start with **Phase 0** (SHA-256 in `Version.Hash`) — cheap, isolated, and a
prerequisite for everything else — then commit to **Phase 1** as a dedicated effort with the
SHA-1 suite as a continuous regression gate. Reftable (the other Tier-6 item) is more
self-contained if a smaller next step is preferred.
