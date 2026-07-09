# Testing

The test suite is AUnit-based and is intended to run without public internet access. Git compatibility tests use local temporary repositories and the system `git` command.

Tests are split across the two crates: the **functionality** suite lives in the `versionlib` crate (`../versionlib/tests`) and the **CLI** suite (CLI parsing, hooks, documentation, and CLI-integration tests that drive `bin/main`) lives in this crate (`tests`). The CLI suite must run from the `version/` crate root so the integration tests find `bin/main` and the documentation tests find `docs/`.

Expected local verification path:

```sh
alr build
alr exec -- gprbuild -P tests/tests.gpr
./tests/bin/tests
(cd ../versionlib/tests && alr exec -- gprbuild -P versionlib_tests.gpr && ./bin/tests)
alr exec -- gprbuild -P tools/tools.gpr
```

The Phase 40/43 archive tests live in `tests/src/version-archive-tests.adb`. They cover TAR and ZIP export from committed trees, dirty-working-tree independence, pathspec filtering including exclusions and no-match output, tagged and branch revision selection, executable mode metadata, sparse-checkout independence, documented gitlink placeholder handling for both TAR and ZIP, symlink metadata preservation, malformed output rejection, unsafe archive entry path rejection including control characters, empty path components, and regular-file names ending in slash; unsafe symlink-target rejection from both writer calls and committed object data, case-insensitive unsupported compressed output rejection with stable diagnostics, deterministic repeated archive generation and repeated entry ordering, long TAR ustar paths, explicit TAR/ZIP directory-entry preservation, empty ZIP directory/file writing, empty/missing revision rejection, unsupported archive tree file-mode rejection, binary/CRLF/compressed-looking payload extraction, cross-format file-set plus byte-preservation equivalence, hostile object-database tree entry rejection, temporary-output cleanup after failed archive export, and preservation of preexisting output files after failed exports.

The Phase 39 documentation tests live in `tests/src/version-documentation-tests.adb`. They verify that required documentation and example files exist, are non-empty, cover the implemented command surface, and keep compatibility limitations visible.

The copy-paste example smoke tool is:

```sh
tools/bin/check_examples
```

It intentionally runs only local deterministic workflows. HTTP and SSH examples describe replaceable remote URLs and are not contacted by normal release verification.

For compatibility smoke repositories, run `version verify` and `git fsck --strict` after mutations. A conservative release pass should also inspect package contents with the release-package tool and confirm that generated build artifacts are absent.

Merge tests include signed merge object emission with a fake local `gpg`, configured external merge-driver resolution for blob conflicts, clean multi-target `--no-commit` continuation through multi-line `MERGE_HEAD`, autostash application onto no-commit results, and simple and ambiguous directory-rename addition handling.

## Optional Phase 41 benchmark tools

The Phase 41 scalability work includes optional benchmark entry points under `tools/`.
They are not part of the normal unit-test suite and should not be used as pass/fail
timing gates. They report elapsed time and simple operation/output counts for local
comparison while tuning cache-aware paths:

```text
bench_status [iterations]
bench_log [iterations]
bench_archive [output.tar] [revision]
bench_object_lookup [iterations]
```

Run them from a deterministic repository fixture when comparing changes. Prefer
counter- or behavior-based regression tests for required verification; benchmark
numbers are diagnostic only.

### Phase 41 non-timing regression checks

The scalability checks should stay counter- or behavior-based rather than timing-based.  For caches, assert bounded decoded-object/tree counts after repeated reads instead of elapsed time.  For hashing and pack writing, compare deterministic checksums and Git compatibility rather than timing or process memory. For receive-pack, compare file-backed request assembly against the canonical in-memory request for byte identity. For fetch, the important behavior is that smart-HTTP upload-pack response chunks are demuxed into a temporary pack stream and then indexed after the stream is complete; tests should avoid asserting wall-clock timing or platform-specific buffer counts. Diff/status/archive scalability checks should prefer semantic path-selection fixtures, duplicate-entry behavior, and lookup counters over wall-clock thresholds. Ordering scalability should be covered through semantic ordering fixtures and existing output comparisons rather than timing thresholds; optimized sort implementations must preserve the previous deterministic path/object order. Pathspec-aware status tests should verify matching tracked modifications and matching untracked files are still reported while non-matching untracked files are excluded; they should not depend on timing or platform-specific filesystem permission failures. Pathspec-aware diff tests should include a matching tracked modification alongside a non-matching tracked deletion so the optimized scan and indexed working-side matching preserve path-filtered output semantics. Maintenance/reachability scalability checks should assert duplicate roots, shared trees, loose-object discovery, and unreachable loose objects semantically, while relying on ordered-set/cache instrumentation rather than timing. Restore scalability checks should assert behavior, such as restoring an earlier commit while removing paths that exist only in the current index, and cache diagnostics, such as full commit restore plus index materialization reusing one flattened tree cache, instead of measuring elapsed time. History and branch-tracking scalability checks should remain semantic as well: linear ancestry, merge-base, reachable-object collection, duplicate pending commits, shared tree traversal, and divergent ahead/behind counts should be asserted through correctness fixtures or cache/set counters, not elapsed time. Shallow-boundary scalability tests should verify command-local cache semantics directly: an already-loaded shallow cache must not reread after file mutation until explicitly cleared, and callers should use the cache in long log/history/maintenance/reachability walks rather than calling `Version.Shallow.Is_Shallow_Boundary` repeatedly.


### Phase 41 packed-ref cache regression

The refs test suite includes a non-timing regression that resolves packed refs through `Version.Ref_Cache`, verifies the packed-ref table is cached once, confirms the cache does not implicitly reread after file mutation, and confirms `Clear` reloads the current `packed-refs` content. Ref transaction tests also cover packed-only deletes, loose-over-packed deletes, expected-old mismatch preservation so packed-ref rewrites remain failure-before-mutation, and stale detached HEAD expected-old preservation for direct HEAD writes. The release preflight also runs `tools/bin/check_ref_write_policy` so future production ref mutations cannot bypass the transaction/expected-old APIs with direct `Atomic_Write_Ref` calls outside `Version.Refs`.

- Branch integration abort coverage continues to verify target-only files are removed; Phase 41 now exercises that behavior through cache-aware tree flattening and ordered path membership rather than repeated linear scans.

- Phase 41 replay/stash scalability checks should prefer cache counters or semantic replay/apply regressions over timing assertions; cherry-pick, revert, rebase, and stash apply cache lifetimes must remain command-local. Stash tests also cover pathspec-limited push for tracked changes, no-match behavior, selected untracked/ignored-file handling, show summary/patch/pathspec inspection, pathspec apply/pop behavior, selected-apply preflight/no-partial-write behavior through shared untracked restore helpers, CLI routing and no-match feedback for stash pathspec/store-message forms, create/store plumbing, store default-message/message-override/validation behavior, clear cleanup, and branch-from-stash success/failure/drop semantics.


### Phase 41 shallow update regression checks

Shallow metadata tests cover deterministic shallow-file normalization, duplicate removal, command-local shallow cache behavior, and malformed input rejection.  Fetch shallow-update logic is structured to use ordered membership sets for existing and unshallow ids so large shallow boundary lists avoid nested vector scans without relying on timing-sensitive tests.

- Run `tools/bin/check_release_ready` from a built tools project for the full local release preflight.
- Run `tools/bin/check_release_consistency_selftest` when changing release consistency rules.
- Run `tools/bin/check_release_package_selftest` when changing release package-shape rules.


### Phase 43 Git compatibility end-to-end matrix

The Git compatibility regression suite lives in `tests/src/version-git_compat-tests.adb`. It exercises local end-to-end workflows using the system `git` command after Version mutations: `git fsck --strict` and `git log` after save/amend/revert/cherry-pick/rebase-continuation commits, `git status --porcelain` after restore/stage/branch switching and resolved rebase continuation, `git checkout` of Version-created history and Version-created rebase continuation commits, `git archive` against Version-created trees, `git submodule status` against Version-created gitlinks, and extraction of Version-created TAR archives with system `tar`. These tests are release-acceptance checks for on-disk compatibility and should remain local-only and deterministic.


### Phase 43 transport failure mutation-safety coverage

The transport regression suite includes local, HTTP upload-pack, HTTP receive-pack, HTTP/2 streaming-option coverage without public internet access, and fake-SSH subprocess streaming fixtures for failure atomicity.

Covered fetch cases include malformed upload-pack pkt-lines, truncated pack payloads, upload-pack fatal sideband packets, unknown sideband channels, empty/missing-object pack responses, HTTP discovery failure, shallow capability/fatal failures, HTTP/SSH tag-advertisement failures before a valid pack is accepted, SSH backend failure, and local packed-head/tag-lock fetch rollback for copied objects after final ref-transaction failure, plus mixed tag/head transaction rollback. Push coverage includes HTTP receive-pack report-status rejection, network/drop-before-report-status behavior, remote unpack errors, non-fast-forward report-status rejection, partial report-status, local non-fast-forward rejection, conflicting tag rejection, local server-side hook preservation on successful and failed pushes, local copied-object rollback when the final remote ref transaction fails including packed remote branches, local tag batch transaction rollback including packed remote refs, and stale local-path remote branch/tag detection immediately before expected-old final ref transactions, and expected-old protection for receive-pack remote-tracking updates.

These tests assert that failed fetches and pushes do not create remote-tracking refs, do not partially apply advertised tag updates, do not mutate existing remote-tracking refs or local tracking assumptions, do not mutate working-tree sentinels, do not leave temporary fetch/push pack artifacts, and preserve existing `.git/shallow` metadata when shallow negotiation fails.

Ref-integrity tests cover pack-refs rejecting malformed loose branch and tag refs before rewriting `packed-refs`, and maintenance/gc rejecting malformed nested branch, tag, and remote-tracking refs with full-ref diagnostics before object cleanup. Ref-read hardening covers HEAD validation, malformed loose-ref cache recovery without poisoning, current-commit cache semantics for attached and detached HEADs, branch/tag existence checks for malformed loose refs, remote-prune handling of malformed tracking refs including dry-run parity, expected-old stale-delete protection, and packed-delete transaction rollback, and submodule packed-ref rejection. Existing-ref preservation is explicitly checked across malformed pkt-line, truncated pack, upload-pack fatal, unknown sideband, missing-object/empty-pack, HTTP discovery, shallow negotiation, HTTP/SSH tag-advertisement failure, SSH backend, ref-transaction loose/packed rollback, branch/tag/stash/replay ref mutations routed through expected-old transactions, detached HEAD save/replay writes protected by expected-old checks, transaction-local rollback artifact cleanup/collision handling, packed-refs lock cleanup/stale-lock preservation, atomic replace target preservation/shared validation/direct routing/rollback sidecar preservation/rollback cleanup/backup-rollback exhaustion, pre-apply conflicts, local push stale-ref diagnostics, local push expected-old final ref transactions, receive-pack remote-tracking expected-old mismatch preservation, fetch remote-tracking expected-old mismatch preservation, and push receive-pack failure modes.

Atomic replace rollback coverage treats pre-existing rollback-looking sidecars as caller-owned data: direct replacement preserves them, backup rollback cleans only artifacts it allocates, and exhaustion preserves all occupied rollback sidecars.


### Phase 43 hook execution semantics coverage

The hook regression suite covers the frozen client-side hook contract for supported hooks. It verifies that `post-commit` observes the updated `HEAD`, sees the committed message, runs from the repository root, receives hook environment variables including `GIT_COMMON_DIR` and `GIT_INDEX_FILE`, sanitizes Git-local repository-selection variables for merge hooks while restoring the caller environment afterward, reports non-zero exits after commit mutation without rollback, is skipped when commit creation is blocked by `pre-commit`, `pre-merge-commit`, or `commit-msg`, is skipped for unchanged/no-op saves, is skipped when object storage prevents commit completion, and is suppressed when hooks are disabled. It also covers stable hook-failure CLI diagnostics, stable empty hook-output capture, POSIX non-executable hook no-op behavior, unsafe hook-name rejection, and symlinked POSIX hook no-op behavior so hook execution remains confined to ordinary executable files in `.git/hooks`. Rebase continuation tests additionally verify that a failing `post-commit` is reported only after the completed continuation commit remains Git-readable and the completed rebase state is not rolled back. Rebase and cherry-pick conflict tests preserve existing `.git/rr-cache` metadata when rerere is disabled, while rebase, cherry-pick, and revert rerere tests verify preimage creation, postimage recording on successful continuation, and recorded-resolution reuse on repeated replay conflicts. CLI tests reject unsupported interactive and merge-preserving rebase modes before refs, rebase state, or dirty working-tree files are mutated.


### Phase 43 hostile tree/path safety coverage

The security regression suite includes raw-object hostile tree fixtures for traversal, literal `.git`, `.git/hooks`, empty path components, trailing slashes, absolute paths, and archive export entry-name rejection. These tests must assert both the expected `Data_Error` and the no-mutation invariant: existing working-tree sentinels and archive outputs must remain unchanged after rejection. Path normalization rejects duplicate separators as empty components rather than silently collapsing them, so tree entries such as `a//b` are treated as hostile input. Repository gitdir safety tests cover local-transport `.git` indirection rejection for escaping or malformed gitdir files, invalid object entries, and object path collisions without copying objects. Submodule gitdir tests reject escaping and normalized-escaping gitdir indirection before status/HEAD resolution.



### Phase 43 restore/submodule gitlink interaction coverage

Restore regression tests cover POSIX symlink materialization from committed/index `120000` entries and submodule boundaries during directory restore. Working-tree directory restores must preserve gitlink entries, restore ordinary files in the parent directory, and avoid recursing into or overwriting submodule worktree contents. Staged directory restores must preserve `160000` gitlink mode and the selected source gitlink object id while leaving submodule working-tree files untouched. Second-pass coverage also verifies source-missing gitlinks: working-tree-only restores preserve existing submodule worktrees and index gitlinks, while staged restores remove source-missing gitlink index entries without deleting submodule worktree files. Direct gitlink path restores preserve submodule directories, and ordinary files blocking a gitlink path are rejected before mutation.


Submodule status display tests freeze the stable status labels used by `version submodule status`: clean, missing, new commits, and dirty. These tests complement the submodule URL, gitdir, sparse-exclusion, linked-worktree admin-dir isolation, and restore/gitlink tests by keeping the user-facing read-only inspection output deterministic.

Worktree display tests freeze `version worktree list` markers for primary/current, linked branch-in-use, missing linked paths, and detached linked worktrees. They also freeze `version worktree current` text for primary and linked worktree contexts and verify that missing linked worktree metadata remains visible instead of silently disappearing from inspection output.

### Phase 43 submodule URL edge-case coverage

Relative submodule URL tests cover successful resolver behavior for HTTPS, SSH, scp-like, file, and local bases, including remotes without `.git`, trailing-slash remotes, SSH remotes with explicit ports, deeper legal traversal, `./../` normalization, backslash separator normalization, and preservation of absolute URLs. Negative cases must reject excessive `..` traversal for every supported base shape, backslash traversal, duplicate/empty relative URL components, control characters, empty/pathless remotes, and malicious `.gitmodules` paths before clone/update mutation. Resolver-level tests should remain network-free; integration tests should only use local repositories.

### Phase 43 platform-specific safety coverage

The platform regression suite covers Windows path-policy behavior through portable simulation tests: drive-root and drive-relative paths, UNC-like roots, slash-absolute paths, reserved device names with case and extension variants, and backslash or mixed-separator traversal must be rejected before checkout/write paths are used. POSIX fixture tests cover symlink parent/write/delete/preflight rejection and permission-denied atomic writes. POSIX symlink tests assert that rejection does not materialize files through the symlink or delete the symlink target; the permission-denied atomic-write test preserves original content and temporary-file cleanup when the host permission model enforces the read-only directory fixture.


### Object and pack corruption coverage

The Phase 43 corruption suite now includes negative fixtures for malformed loose objects, malformed tree/commit objects, truncated packs, bad pack trailer checksums, missing ref-delta bases, and truncated pack indexes. These tests assert deterministic `Data_Error` rejection and, for pack ingestion failures, that no generated `.idx` file is left behind.

### Command-boundary corruption coverage

Command-boundary corruption tests live in `tests/src/version-command_corruption-tests.adb`. They complement the low-level object/pack corruption tests by exercising release-facing commands against corrupt repository state: status and stage reject corrupt indexes without rewriting them, save rejects corrupt index state before branch/ref/reflog mutation, log rejects malformed commit graphs cleanly, restore rejects corrupt source trees without changing working-tree files, branch switch rejects corrupt target trees and corrupt blobs without moving HEAD or materializing partial checkout files, archive export rejects corrupt trees/blobs without replacing preexisting output archives, submodule command boundaries reject malformed/corrupt .gitmodules state without mutation, fetch rejects corrupt local objects for advertised remote commits before updating existing remote-tracking refs, stash create/store/show/apply reject corrupt index or stash object state without updating the stash stack or writing partial selected paths, and stash list/drop/pop/branch/clear cover malformed reflog, missing targets, and refs/stash-versus-reflog split-brain storage without unintended mutation.

### Fetch-ingestion corruption mutation safety

Phase 43 adds fetch-level corruption fixtures for HTTP upload-pack responses that carry bad pack checksums, missing delta bases, or object data that does not provide the advertised commit. These tests assert that failed ingestion does not create or rewrite remote-tracking refs and removes temporary `tmp-version-fetch.pack` / `tmp-version-fetch.idx` artifacts.



### Phase 43 unsupported-format command coverage

Repository-format tests cover repository-format extensions at command boundaries, not only at the low-level format parser. `extensions.objectFormat = sha256` is a supported object format (`Sha256_Object_Format_Is_Compatible`); the still-unsupported cases (e.g. `refStorage = reftable`) must be rejected before mutation. Format version 1 with `extensions.partialClone` is compatible, and branch creation plus merge cover that partial-clone metadata no longer blocks ordinary operations when required objects are already available; branch creation still covers unsupported `extensions.worktreeConfig`. The tests assert preservation of working-tree sentinels, index bytes, branch refs, HEAD reflogs, and existing remote-tracking refs for unsupported formats so rejection stays a stable, precise diagnostic.

### Phase 43 CLI golden-output freeze breadth

The CLI tests freeze `version --help`, `version -h`, `version --version`, `version help COMMAND`, and command-specific help aliases before broader release-critical output fragments. The CLI tests now freeze release-critical output fragments at stable seams instead of relying on brittle whole-process transcript captures. The suite covers top-level help, selected command help, clone/fetch/push/archive/submodule/worktree/sparse help fragments including `sparse status`, unknown-command diagnostics, missing-operand diagnostics, clean and dirty status line fragments, status porcelain/short alias equivalence, diff staged/cached alias equivalence, tag list --points-at exact-match/help seams, tag list --contains reachability seams, tag exists predicate/help seams, tag resolve help/output seams, tag peel output seams, tag show inspection seams, log oneline formatting/help seams, unsupported object-format diagnostics, branch-switch failure diagnostics, clone/fetch/push/archive/submodule/worktree/sparse failure diagnostics including stale local push branch/tag checks, per-command corruption diagnostics, transport failure diagnostics, hook failure diagnostics, and redaction of internal/temp-path details. The frozen contract is exit code, first diagnostic line/prefix, classification, and absence of debug/internal leakage. Clone package tests cover target rollback after fetch failure and after default-branch checkout failure, while preserving source refs. Tag tests also cover peeled target matching for `tag list --points-at REV`; reachability matching for `tag list --contains REV`; quiet tag-existence predicates for loose, packed, missing, and invalid tag names; resolving loose, packed, and annotated tag refs; peeling lightweight, packed, and annotated tag refs; showing lightweight, annotated, packed, and missing tag details; native annotated tag creation; explicit lightweight and annotated tag targets; and rejecting missing tags without mutation. Log tests cover compact oneline output and preserve newest-to-oldest traversal semantics. Sparse tests cover `version sparse status` enabled/disabled output and no-mutation behavior. Unsupported advanced pathspec magic such as `icase` and `from-file` is covered both by parser diagnostics and CLI command-boundary rejection, including a mutating stash path that preserves dirty files and creates no stash. Attribute pathspec coverage verifies set, unset, unspecified, and value matching against repository `.gitattributes`.



## Platform CI confirmation

Platform-sensitive tests must be run on real hosts before release. The POSIX gate is `tools/bin/check_platform_ci_matrix posix`; the Windows gate is `tools/bin/check_platform_ci_matrix windows`. These gates build the project, build and execute the full AUnit suite, and run the release consistency, ref-write-policy, and ref-transaction checks available on the host; the POSIX gate also runs the related self-tests. When `VERSION_PLATFORM_CI_EVIDENCE_DIR` is set, the gates write `platform-posix.txt` and `platform-windows.txt`; verify those artifacts with `tools/bin/check_platform_ci_evidence .release/platform-ci-evidence; summarize with tools/bin/summarize_release_evidence .release/platform-ci-evidence`. The copy-ready CI template is `ci/github-actions-platform-matrix.yml` and includes an evidence-verification job. A release is not platform-confirmed until both gates pass for the exact source tree being released and their evidence files verify.

### Phase 43 cross-feature interaction matrix

The cross-feature regression suite lives in `tests/src/version-cross_feature-tests.adb`. It verifies combined release invariants rather than isolated helpers: sparse directory restore must preserve submodule gitlink boundaries, sparse-excluded submodule restores must fail without touching dirty submodule worktrees or gitlink index entries, linked-worktree restores must not alter the primary worktree's gitlink state, `post-commit` hooks invoked from linked worktrees must run with the linked root as both cwd and `GIT_WORK_TREE`, and archive export must remain object-based by preserving committed gitlink placeholders even when sparse checkout omits the submodule path. Fetch tests also include corrupt shallow fetch cases that preserve both existing remote-tracking refs and `.git/shallow` byte-for-byte.



### Phase 43 release package negative self-tests

`tools/bin/check_release_ready` is an Ada preflight runner that executes the build, AUnit, example, documentation, test-scope, ref-write-policy, ref-write-policy self-test, release-consistency, and package-shape gates in the intended local release order.

`tools/bin/check_release_package_selftest` builds clean and intentionally broken source archives and verifies `tools/bin/check_release_package` rejects generated artifacts, nested generated archives, missing required release documents, missing release checker scripts, and missing platform CI gates. The negative cases cover `obj/`, `bin/`, `.ali`, `.o`, nested `.zip`/`.tar`, missing README/CHANGELOG/release notes/checklist, missing `check_release_consistency`, and missing POSIX/Windows platform gate scripts.


## Test-scope completeness gate

`tools/bin/check_test_scope_completeness` is the release-facing guard for Phase 43 feature/test-scope closure. It verifies that the release-critical AUnit suites remain present and registered, checks for coverage markers for unsupported-format no-mutation behavior, LFS pointer ordinary-file preservation plus attribute-gated restore smudge and local/HTTP/SSH-authenticated merge transfer, upload-pack blob-filter request construction, CLI output freeze, hook semantics, Git compatibility including rebase, unsupported rebase mode rejection, rerere replay preimage/postimage reuse, server-side hook non-support, local fetch copied-object rollback with packed heads, tag locks, and mixed tag/head transactions, local push copied-object rollback including packed branch refs, local tag push transaction rollback including packed refs, cross-feature sparse/submodule/shallow interactions, linked-worktree submodule admin-dir isolation, transport mutation safety, push failure handling, archive/gitlink/export-subst behavior, unsupported pathspec magic rejection, attr pathspec matching, sparse-index no-mutation handling, and command-boundary corruption, and enforces the Phase 43 registered-routine floor. Run it before release and whenever adding, renaming, or splitting release-critical suites.


## Documentation coherence gate

`docs/REF_TRANSACTION.md` documents the ref transaction expected-old contract, stable diagnostics, rollback requirements, and release guardrails.

`tools/bin/check_ref_write_policy` is a release-facing guardrail for ref mutation hygiene. It fails if production Ada sources call `Atomic_Write_Ref` outside `Version.Refs`; semantic branch, tag, stash, fetch, push, replay, and known-old detached HEAD updates should use expected-old transactions or expected-old HEAD helpers instead. Test fixtures may still call the low-level writer for setup and corruption coverage. `tools/bin/check_ref_write_policy_selftest` verifies the policy checker passes the current tree and fails a fixture that injects a forbidden production `Atomic_Write_Ref` call. `tools/bin/check_ref_transaction_selftest` verifies the ref transaction expected-old contract, stale diagnostics, create-only zero-id behavior, rename-style stale-delete cleanup, and lock/rollback cleanup outside the AUnit runner. `tools/bin/check_platform_ci_evidence_selftest` verifies the platform evidence checker and release evidence summarizer accept complete POSIX/Windows evidence and reject missing or bad `ref_write_policy=passed` and `ref_transaction=passed` markers.

`tools/bin/check_documentation_coherence` is a release-facing smoke check for documentation drift that is not covered by the command/test-scope gates. It verifies that README release commands remain copy-pasteable, release notes start with the baseline release narrative, stale implementation diagnostics are absent, and the authoritative release/package docs still list the required release gates.

## Unsupported-feature diagnostics

`Version.CLI.Tests` verifies precise unsupported-feature diagnostics for unsupported object formats (anything other than `sha1`/`sha256`), promisor sidecars without a configured partial-clone remote, HTTP/3, h2c, server push, and unsupported remote URLs. LFS coverage verifies pointer files are treated as ordinary blobs/files when no LFS filter attributes apply, verifies `filter=lfs` staging cleans media into pointer blobs and local LFS storage, verifies restore materializes cached media for `filter=lfs` paths, and verifies merge smudge from available local media plus missing-media transfer from configured local `lfs.url` stores, HTTP Git LFS batch download endpoints, and SSH `git-lfs-authenticate` command construction. Object coverage freezes missing-object diagnostics for promisor pack sidecars without a configured remote, verifies partial-clone object reads lazily fetch missing objects from a configured local promisor remote, and freezes upload-pack `filter blob:none` request construction for advertised smart promisor fetches. Command-level unsupported-format tests also assert no-mutation behavior for user-facing commands. Sparse-index command-boundary tests assert that `sdir` sparse-directory entries are expanded for reads, that stage and merge desparsify the rewritten index, and that no-op save can read sparse index state without moving refs or appending reflogs.
## Doctor command tests

The CLI tests freeze the `version doctor` output surface and the `version doctor --release` release-gate script list. The command is a convenience wrapper only; the authoritative release validation remains the shell gates plus full AUnit execution on the platform matrix.

The CLI stash diagnostics tests freeze malformed stash reflog, broken old-id chain, and refs/stash-versus-reflog mismatch failures at the command boundary. They assert command-failure exit status, stable `error:` output, no temp-path or exception-name leakage, and no mutation of stash refs, reflogs, or working-tree files for the covered list/show/apply/drop paths. The malformed-reflog and inconsistent-storage messages are exposed through public `Version.Stash` diagnostic functions so implementation errors and CLI output tests share one contract. Command-corruption tests also cover strict stash reflog line-shape validation for old/new object IDs, separators, tab-delimited messages, old-id chain consistency across multi-entry stash stacks, and no-mutation preservation. Shared stash storage fixture helpers live in `Version.Stash_Test_Support` so command-boundary, CLI corruption, and ordinary stash suites build or inspect stash ref/log paths consistently. The stash suite also covers the helper formatting contract directly: ref/log paths, strict reflog line shape, broken-chain fixture generation, and synthetic stash storage writes.


## Command unavailable diagnostics

`Version.CLI.Tests` freezes the central command-unavailable diagnostic surface in `Version.Availability`. These tests cover missing repository, missing active branch, no staged changes, missing remotes, missing upstream, unsupported repository-format preconditions, linked-worktree safety, outside-worktree paths, sparse-excluded paths, and branches already checked out by another worktree.

The CLI golden-output suite freezes archive UX diagnostics for unsupported formats and unsafe prefixes.

### Release edge-case examples

`docs/EDGE_CASE_EXAMPLES.md` provides copyable examples for the release-hardened edge cases covered by the Phase 43 regression suite: restore with submodule gitlinks, archive unsafe path rejection and output preservation, unsupported-format rejection (e.g. reftable refs), `post-commit` no-rollback behavior, transport failure no-mutation guarantees, and the platform CI evidence workflow. Keep these examples aligned with the tests and release-facing diagnostics.

Config tests freeze the `version config list`, `version config keys`, `version config get KEY`, `version config has KEY`, `version config set KEY VALUE`, and `version config unset KEY` contracts, including quoted subsection rendering such as `remote.origin.url`, deterministic `section.key=value` lines, key-only output, direct value lookup, quiet key-existence predicates, deterministic key creation/update, missing-key failure, selected-key removal, unrelated-entry preservation, and no-mutation behavior for inspection commands.

- Branch tests freeze the read-only `version branch current` output surface for attached HEADs and detached-HEAD rejection. They also cover `version branch exists NAME` for existing, missing, invalid-name, and no-mutation behavior; `version branch resolve NAME` for loose/packed branch tips, missing/invalid-name rejection, and no-mutation behavior; `version branch upstream [BRANCH]` for current/named branch output, missing-upstream rejection, missing-branch rejection, and no-mutation behavior; `version branch contains REV` for included/excluded branch tips, unknown-revision rejection, and no working tree/index mutation, plus `version branch merged [BRANCH]` and `version branch unmerged [BRANCH]` for current/named-base reachability, missing-base rejection, and no-mutation behavior.

- Remote tests freeze the stable tab-separated `version remote list` output surface, the read-only `version remote get-url NAME` URL-only output surface, the quiet `version remote exists NAME` predicate, `version remote set-url NAME URL` update behavior including missing-remote rejection and fetch-refspec preservation, `version remote rename OLD NEW` behavior including missing-source rejection, destination-collision rejection, URL preservation, and fetch-refspec preservation, `version remote prune NAME --dry-run` stale-ref reporting including packed-ref no-mutation parity and malformed loose-ref ignore behavior, and `version remote prune NAME` stale-ref deletion with live-ref preservation. Mixed loose/packed duplicate remote-tracking refs are covered as single logical refs for dry-run reporting and deletion, and nested remote-tracking branch names are covered for loose and packed refs. Prune coverage includes local and packed remote-tracking refs, mixed loose/packed duplicate refs, nested loose/packed branch names, live packed-ref preservation by branch name, expected-old delete protection including stale-value rejection and loose/packed multi-ref atomicity, packed-lock rollback, dry-run discovery failure atomicity, malformed remote packed-refs dry-run atomicity, plus SSH upload-pack discovery failure atomicity.


### Phase 43 branch-list alias and remote-prune coverage

Branch command regression coverage freezes the read-only branch reachability helpers and their `branch list` aliases: `branch list --contains REV`, `branch list --merged [BRANCH]`, and `branch list --no-merged [BRANCH]` must remain equivalent to the underlying `contains`, `merged`, and `unmerged` commands. CLI merge coverage freezes `version merge [OPTIONS] [TARGET...]` as the Git-facing entry point, including upstream default-target routing, expanded merge option parsing, Git-style already-up-to-date/fast-forward/clean-merge/no-commit success text, Git-style typed conflict summary diagnostics including rename/delete, rename/rename, and directory-rename file-location without the internal generic conflict error, signature verification preflight failures, `--no-ff`, `-m`/`-F`, `--edit`, `--quiet`, `--verbose`, `--progress`/`--no-progress`, `--autostash`, `--no-commit`, multi-target squash, Git merge-state files, `--continue`, and `--abort`/`--quit` parsing. Branch merge regression coverage also verifies Git-style unmerged index stages, `AUTO_MERGE`, conflict styles, deterministically ordered recursive criss-cross virtual bases, conflicted textual, binary, delete/modify, directory/file, rename/delete, rename/rename, and directory-rename virtual-base materialization without silent first-base fallback, multi-line text auto-merge, auto-merged text plus one-sided mode preservation, clean symlink materialization including `core.symlinks=false` plain-file fallback, default and selected diff-algorithm multi-hunk insertion merge including explicit Myers parsing, merge ff/log/signoff/cleanup/edit/autostash/pre-merge-commit hook behavior, merge renormalize config and override behavior, scoped merge attribute precedence plus text and unset resets, external driver shell-quoted path placeholder, label, and environment expansion, fatal-status and missing-result propagation with temp cleanup, and recursive built-in/delegated handling for virtual-base merges, rerere preimage/postimage reuse including swapped-side reuse, autoupdate-only preimage recording, and replay preimage/postimage reuse for rebase, cherry-pick, and revert, rename/modify preservation, case-only rename preflight under case-insensitive policy, filesystem guard UTF-8 normalization collision preflight, same-path rename/rename edits, same-path rename/rename mode preservation, rename/add collision staging, simple directory-rename additions, generated directory-rename case-collision preflight, ambiguous split-directory rename conflicts, directoryRenames=false/conflict behavior, copy-base add/add handling, ignore-cr-at-eol behavior, resolve-strategy rename disabling, renameLimit behavior, subtree path rewriting, rename config override behavior, gitlink handling including dirty tracked/untracked checked-out submodule refusal and recursion control, octopus commits, octopus conflict head recording, and single-target octopus strategy rejection and multi-target two-head strategy rejection, directory/file conflicts, mode/content combination, identical-content plus mode preservation, and continue/abort handling for Git-created conflicted merge state. Remote-prune tests cover loose and packed dry-run output with no-mutation behavior, malformed loose tracking-ref ignore behavior, mixed loose/packed duplicate logical refs, nested loose/packed tracking refs, loose stale tracking-ref deletion, packed stale tracking-ref deletion, live packed-ref preservation by branch name, expected-old stale-delete rejection, loose/packed multi-ref expected-old atomicity, packed-lock transaction rollback, preservation of live and unrelated packed refs, and failure-before-mutation behavior when remote discovery fails or remote packed refs are malformed for both prune and dry-run prune.
