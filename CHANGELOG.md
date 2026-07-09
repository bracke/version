- Large `clone`/`fetch` over smart transport is now fast: the zlib inflater was copying its 256 KiB Huffman decode table on every decoded symbol, so decompressing a received pack ran at ~80 KB/s; a 500 KB clone that took ~25s now takes ~1s and multi-MB clones no longer stall. Pack indexing also no longer inflates each object twice.
- `clone`/`fetch`/`push`/`pull` over native SSH additionally interoperate with block-cipher connections that use an Encrypt-then-MAC MAC (e.g. `hmac-sha2-256-etm@openssh.com`), which previously failed the handshake.
- `clone`/`fetch`/`push`/`pull` over native SSH now interoperate with the `umac-64@openssh.com` and `umac-128@openssh.com` MACs (and their `-etm` variants): the bundled UMAC was a non-standard placeholder that a peer rejected with "Corrupted MAC", and has been replaced with a correct RFC 4418 UMAC-64/128 implementation, verified against the RFC test vectors and against live OpenSSH.
- The `diffie-hellman-group16-sha512` and `diffie-hellman-group18-sha512` key exchanges now interoperate with OpenSSH. Two bugs: the bundled group18 modulus was not the RFC 3526 8192-bit MODP prime (it was a corrupted ffdhe8192 value), and — more fundamentally — the 4096-bit (group16) and 8192-bit (group18) modular exponentiations overflowed GNAT's `Big_Integers` (~6400-bit cap) and raised `STORAGE_ERROR`, so both groups failed the handshake regardless of the prime. The group18 prime is now the exact RFC 3526 value, and a fixed-width Montgomery modular-exponentiation (`CryptoLib.Modexp`) replaces `Big_Integers` for group16/18, verified against a known-answer vector, against `Big_Integers` at group14 size, and by live handshakes against OpenSSH 10.3p1. group14/group1 are unchanged (already correct and within the cap).
- The `sntrup761x25519-sha512` post-quantum key exchange (preferred by OpenSSH 8.5–9.8, before ML-KEM) now interoperates with OpenSSH: the bundled Streamlined NTRU Prime 761 was a placeholder that did no NTRU-Prime arithmetic (keygen derived the public key from a hash of a seed; encaps/decaps never touched the ring), so a peer rejected the handshake. It has been replaced with a faithful implementation of the reference KEM — R3/Rq polynomial reciprocals, the recursive radix Encode/Decode, rounding, weight-w sampling, and the SHA-512 prefix/confirm/session hashing — verified byte-exact against the OpenSSH reference (decapsulation KAT plus bidirectional encaps/decaps interop) and by a live handshake against OpenSSH 10.3p1.
- The `mlkem768x25519-sha256/512` post-quantum key exchanges now interoperate with OpenSSH (9.9+): the bundled ML-KEM-768 implementation followed the FIPS 203 draft/Kyber round-3 conventions and was rejected by conforming peers, and has been corrected to the final FIPS 203 standard (module-rank domain separation, the simplified FO transform and implicit-rejection key, correct RejNTTPoly sampling, NTT/inverse-NTT, and NTT-domain arithmetic), verified against the pq-crystals reference. The X25519 half of the hybrid shared secret was also being byte-reversed and is now combined in the raw form the standard requires, and the hybrid session-key derivation now frames the shared secret as an SSH string (not an mpint) as the standard requires — verified by a live handshake against OpenSSH 10.3p1.
- Fixed a hang in `clone`/`fetch` over smart transport (HTTP and SSH): indexing a received pack determined each object's compressed length by re-inflating a growing slice byte-by-byte until it matched (O(pack²)), which pinned the CPU on any non-trivial object. The boundary is now found with a single streaming inflate that reports the bytes consumed.
- Git parity: `version clone/fetch/push` over native SSH now interoperates with real OpenSSH end-to-end for every negotiated cipher — chacha20-poly1305, aes256/128-gcm, and aes-ctr — verified by cloning from a live `sshd`. Fixes were in the crypto/transport libraries: correct chacha20-poly1305 and aes-gcm (RFC 5647) framing, a client compression default of `none` first (matching OpenSSH), and a corrected per-packet deflate loop so `zlib@openssh.com` compression also works when negotiated (verified against real OpenSSH with compression on both directions).
- Git parity: added `version init --object-format=(sha1|sha256)` to create SHA-256 repositories. All commands — stage, save, log, status, show, diff, ls-tree, cat-file, hash-object, branch, merge, rebase, cherry-pick, revert, tag, describe, blame, repack, bundle, reflog, and clone/push/fetch/pull over local and smart HTTP/SSH transport — operate on SHA-256 repositories, matching git's on-disk and wire format (verified against system git, including a real `git http-backend` SHA-256 server). Cloning a SHA-256 remote reproduces its object format.
- Added `version clone --filter=SPEC` (and `--filter SPEC`): creates a partial clone — over HTTP/SSH the filter is negotiated with the server (arbitrary specs sent verbatim), and over local sources `blob:none`/`blob:limit=<n>` are evaluated directly (selective object copy). Omitted objects are lazily fetched from the promisor on first access.
- Repositories with the `extensions.worktreeConfig` extension now open (previously rejected); the per-worktree `config.worktree` is layered over the common config when reading configuration.
- `version push REMOTE` with no refspec now applies the configured `remote.<REMOTE>.push` refspec(s) (each parsed like a command-line refspec, including `+`/`:` forms; multi-valued keys supported), erroring if none are configured.
- `version push --tags --force` now overwrites remote tags that differ from the local tag (previously `--tags` rejected `--force`).
- Added refspec push `version push REMOTE SRC:DST` (and `+SRC:DST` to force, `:DST` to delete): pushes the commit named by `SRC` to remote ref `DST` (branch or full `refs/...`) over local, HTTP, and SSH, refusing a non-fast-forward update unless forced.
- Added `version push --delete REMOTE REF` (and `-d`) to delete a remote branch or tag (local, HTTP, and SSH); errors if the ref is absent and cannot be combined with `--tags`/`--force`.
- Added `version push --force` (and `-f`) to allow a non-fast-forward branch update on the remote (local, HTTP, and SSH); `--tags` does not accept `--force`.
- `push --tags` now works against HTTP and SSH remotes (previously local-only), pushing each tag via receive-pack and refusing to overwrite a differing remote tag.
- Added plumbing commands `read-tree` and `for-each-ref`; `ls-tree` now lists one level by default (subtrees as `tree` entries, six-digit modes) and recursively with `-r`; `symbolic-ref HEAD REF` now sets HEAD without touching the working tree.
- Added plumbing commands `cat-file`, `rev-parse`, `ls-files`, `ls-tree`, `hash-object`, `write-tree`, `commit-tree`, `update-ref`, `symbolic-ref`, `show-ref`, and `rev-list`, with output matching `git` for the supported forms.
- Added `version rebase --rebase-merges UPSTREAM`, replaying topologically and recreating two-parent merge commits to preserve branch structure (octopus merges rejected; aborts on conflict).
- Added `version rebase --root --onto NEWBASE`, replaying the whole branch (including its root commit) onto NEWBASE.
- Added `version rebase -i UPSTREAM` (interactive rebase): a todo is opened in the sequence editor and the edited list replayed, supporting pick, drop, reorder, squash, and fixup. Pick/drop/reorder reuse the rebase state machine (so `--continue`/`--abort` work); squash/fixup run a one-shot executor that aborts on conflict. Reword/edit/exec, `--root`, and `--rebase-merges` remain unsupported.
- Added Tier 3 inspection commands: `version shortlog` (group history by author), `grep` (search tracked files), `describe` (name a commit by the nearest tag), `notes add/show` (commit notes, git-readable), and `blame` (per-line attribution).
- Added `version cherry [-v] [UPSTREAM [HEAD]]` (mark head commits +/- vs upstream by patch-id) and `version range-diff BASE..OLD BASE..NEW` (pair two revisions of a patch series), completing Tier 2's patch tooling.
- Added `version am [MBOX...]`, applying a series of mbox patches and committing each with its preserved authorship and message; consumes `git format-patch` output (author, date, tree, and message reconstructed).
- Added `version format-patch [--stdout] [-o DIR] REVISION`, writing git-`am`-compatible mbox patch files (RFC2822 author date, `[PATCH n/m]` subjects); `git am` of the output reconstructs the identical commit.
- Added `version apply [--check] [PATCHFILE]`, applying a unified diff (modify/create/delete, `-p1`, strict context check, atomic validate-then-write) to the working tree; produces the same result as `git apply` on git-generated diffs.
- Added `version bundle create/verify/list-heads`, reading and writing git-compatible v2 bundles (offline transport): bundles written here clone with `git`, and git's bundles are read here.
- Added `version clean [-n] [-f] [-d] [-x]`, removing untracked files (and untracked directories with `-d`, ignored files with `-x`), refusing without `-n`/`-f` and collapsing untracked directories in its output like `git clean`.
- Added `version mv [-f] SOURCE DEST` (and `mv SOURCE... DIR`), moving tracked files in the working tree and restaging the rename, matching `git mv`.
- Added `version pull [--rebase] [--ff-only] [REMOTE [BRANCH]]`, fetching and integrating the upstream into the current branch (merge with fast-forward, or rebase), and failing when there is no tracking information.
- Added `version reflog [show] [REV]`, printing the ref movement log newest-first in Git's `<short> <ref>@{N}: <message>` format (byte-identical to `git reflog`).
- Added `version reset` with `--soft`/`--mixed`/`--hard` and the path form (`reset [REV] -- PATHSPEC...`), matching Git's HEAD/index/working-tree semantics, writing a `reset: moving to <rev>` reflog entry, and failing before any mutation on an unknown target.
- Aligned merge and branch-switch with Git by allowing untracked working-tree files to be present, refusing only when an incoming path would overwrite an existing untracked file.
- Fixed commit signing and Git/submodule subprocess invocation to resolve the program on PATH (GNAT.OS_Lib.Spawn does not search PATH), so configured gpg and git tools are found.
- Decoded Git-config value escapes (\n, \t, \b, backslash, quotes, inline comments) when reading config, so external merge drivers receive correct newlines and values.
- Corrected CLI merge conflict diagnostics to not misreport modify/delete and rename/rename as rename/delete when an unrelated base file shares the same blob.
- Materialized the executable bit on restore/checkout for mode 100755 entries, and pruned now-empty parent directories when a tracked file is removed.
- Materialized the moved addition as a staged entry for directory-rename conflicts in recursive virtual bases.
- Resolved whole-side whitespace-equivalent auto text merges (e.g. ignore-cr-at-eol) instead of recording a spurious conflict.
- Recorded rerere postimages under the preimage's key via a MERGE_RR path->key map when continuing a merge, rebase, cherry-pick, or revert, so recorded resolutions are reused on later replays.
- Re-applied merge --autostash onto a staged --no-commit merge result by 3-way merging the stash onto the current index tree without requiring a clean working tree or resetting to HEAD.
- Recorded a proper add/add conflict for rename/add collisions instead of auto-merging against the deleted base path.
- Reported working-tree status for symbolic links by hashing the link target (Git's blob content) instead of following the link and hashing the pointed-to file.
- Allowed merge/checkout to replace a tracked symbolic link (unlinking the link itself, with parent-component traversal still rejected), and honored core.symlinks=false by materializing link targets as regular files.
- Smudged LFS pointer media into the working tree on restore/checkout by content-sniffing pointers (not only attributed paths), matching how merge materializes files, so merged LFS entries appear as media.
- Tightened external merge-driver parity by treating a successful driver that removes %A as a driver failure with cleanup.
- Added external merge-driver coverage for shell-quoted path placeholders containing apostrophes.
- Tightened external merge-driver parity by preserving fatal status failures through cleanup and removing internal driver temp files after success or failure.
- Tightened merge CLI ort-output parity by suppressing extra Auto-merging lines for structural rename/delete and directory-rename file-location diagnostics.
- Expanded merge CLI ort-output parity with Git-style file-location diagnostics for directory-rename conflicts.
- Expanded merge CLI ort-output parity with Git-style rename/rename conflict diagnostics for paired destination renames inferred from the merge base.
- Expanded merge CLI ort-output parity with Git-style rename/delete conflict diagnostics inferred from unmerged index stages and the merge base.
- Expanded merge CLI ort-output parity by using Git-style already-up-to-date success output.
- Expanded merge CLI ort-output parity with typed add/add, modify/delete, directory/file, and binary conflict diagnostics.
- Expanded merge CLI ort-output parity by using Git-style fast-forward success output.
- Expanded merge CLI ort-output parity by using Git-style clean-merge and no-commit success messages.
- Expanded merge CLI ort-output parity by emitting Git-style conflict summary diagnostics for recorded merge conflicts without the previous Version-internal generic conflict error.
- Expanded replay rerere lifecycle support so rebase, cherry-pick, and revert conflicts record preimages, record postimages on continuation, and reuse recorded resolutions on repeated replay conflicts.
- Expanded merge hook environment parity by sanitizing Git-local repository-selection variables for hooks while restoring the caller environment after execution.
- Added basic Git attribute pathspec matching for set, unset, unspecified, and exact-value requirements against root `.gitattributes` and `.git/info/attributes` rules.
- Closed the recursive merge strategy parity backlog by ordering multiple virtual merge bases deterministically and rejecting any unmaterialized synthetic-base conflict instead of silently falling back to the first base.
- Expanded recursive merge strategy parity by materializing directory-rename conflicts in synthetic virtual merge bases, preserving moved additions as virtual-base entries while still recording the conflicts.
- Expanded recursive merge strategy parity by materializing rename/rename conflicts in synthetic virtual merge bases, preserving both renamed destinations as virtual-base entries while still recording the conflicts.
- Expanded recursive merge strategy parity by materializing rename/delete conflicts in synthetic virtual merge bases, preserving the renamed side as the virtual base while still recording the conflict.
- Expanded recursive merge strategy parity by materializing directory/file conflicts in synthetic virtual merge bases, preserving the file side as the virtual base while still recording the conflict.
- Expanded recursive merge strategy parity by materializing delete/modify conflicts in synthetic virtual merge bases, preserving the modified side as the virtual base while still recording the conflict.
- Expanded recursive merge strategy parity by materializing binary conflicts in synthetic virtual merge bases, preserving current-side binary content for the virtual base while still recording the conflict.
- Expanded recursive merge strategy parity by materializing textual conflicts in synthetic virtual merge bases instead of falling back to the first base.
- Added smart HTTP/SSH promisor fetch blob-filter negotiation for lazy partial-clone object reads when upload-pack advertises `filter`, emitting `filter blob:none` while retaining fallback for older servers.
- Added attribute-gated Git LFS worktree smudge for restore/checkout: paths marked `filter=lfs` materialize cached or fetchable pointer media while unfiltered pointer files remain ordinary bytes.
- Added attribute-gated Git LFS clean handling for staged files: paths marked `filter=lfs` store media under `.git/lfs/objects` by SHA-256 and commit canonical pointer blobs.
- Expanded merge LFS smudge for SSH remotes by running `git-lfs-authenticate` through the existing direct-argv SSH transport and then fetching media from the advertised HTTP(S) batch endpoint.
- Expanded merge LFS smudge to fetch missing media through HTTP(S) Git LFS batch download endpoints, caching verified media under `.git/lfs/objects`.
- Expanded merge LFS smudge to fetch missing media from configured local/file LFS stores and cache it under `.git/lfs/objects`.
- Added limited partial-clone and merge LFS integration: repository format v1 `extensions.partialClone` is accepted, object reads lazily fetch missing promised objects from the configured promisor remote, and merge worktree writes smudge available local Git LFS media from pointer blobs.
- Expanded `version merge` with common Git-compatible options, arbitrary commit-ish targets, Git merge-state files, post-merge hooks, no-commit/squash flows, strategy favoring, and unmerged status output.
- Expanded merge interoperability with Git index conflict stages, `AUTO_MERGE` tree state, and `version merge --continue`/`--abort` support for Git-created conflicted merge state.
- Added top-level `version merge TARGET|--continue|--abort` over the existing branch integration merge engine.
- Enabled HttpClient HTTPS HTTP/2 ALPN for Git smart-HTTP streaming requests, with HTTP/1.1 fallback and h2c still unsupported.
- Added `version branch list --merged [BRANCH]` and `version branch list --no-merged [BRANCH]` as read-only aliases for `version branch merged [BRANCH]` and `version branch unmerged [BRANCH]`, with help/docs coverage.
- Added `version branch list --contains REV` as a read-only alias for `version branch contains REV`, with help/docs coverage.
- Added read-only `version branch list --verbose` support for compact branch inspection with current marker, short tip id, and commit subject, with help/docs and regression coverage.
- Added read-only `version tag list --points-at REV` support for exact lightweight tag/ref matching, with packed/loose tag, HEAD, unknown-revision, help, and no-mutation coverage.
- Added `version config set KEY VALUE` support for deterministic local config key creation/update while preserving unrelated entries, with stable help/docs/test coverage.
- Added `version config unset KEY` support for narrow local config key removal, with preservation of unrelated entries and stable help/docs/test coverage.
- Added `version remote prune NAME` as a mutating stale remote-tracking ref cleanup, with live-ref preservation, missing-remote rejection, and help/docs coverage.
- Added read-only `version branch upstream [BRANCH]` support for printing configured upstreams as `remote/branch`, with current/named branch, missing-upstream, missing-branch, no-mutation, and help-surface coverage.
- Added read-only `version config keys` support for key-only local config inspection, with stable help/docs and no-mutation regression coverage.
- Added `version remote prune NAME --dry-run` as a read-only stale remote-tracking ref report.
- Added read-only `version branch resolve NAME` support for printing the branch tip object id, with loose/packed, missing/invalid-name, no-mutation, and help-surface coverage.
- Added quiet read-only `version branch exists NAME` support for branch-existence checks, with present/missing, invalid-name, no-mutation, and help-surface coverage.
- Verified the command documentation cleanup so `docs/COMMANDS.md` contains a single `### log` heading in the History section.
- Added read-only `version sparse status` support for printing the current sparse-checkout state as `enabled` or `disabled`, with help/docs and no-mutation coverage.
- Added `version worktree current` to print the current worktree path, primary/linked marker, and branch or detached short id without listing every worktree.
- Added worktree current help/docs coverage and regression tests for primary and linked contexts.
- Added read-only `version branch unmerged [BRANCH]` support for listing branches not yet merged into the current or named branch, with current-base, named-base, missing-base, help, and no-mutation coverage.
- Added read-only `version branch merged [BRANCH]` support for listing branches already merged into the current or named branch, with current-base, named-base, missing-base, help, and no-mutation coverage.
- Added read-only `version branch contains REV` support for listing branches whose tips contain a commit, with included/excluded branch, unknown-revision, and no-mutation regression coverage.
- Added `version remote rename OLD NEW` support for renaming existing remotes, with tests for missing-source rejection, destination-collision rejection, URL preservation, and fetch-refspec preservation.
- Added `version log --oneline [REV]` compact history output, reusing the existing log walk while printing one `<short-id> <subject>` line per commit with help/docs and regression coverage.
- Added read-only `version tag exists NAME` support for quiet tag-existence checks, with loose/packed/missing/invalid-tag regression coverage and help/docs updates.
- Added read-only `version tag resolve NAME` support for printing the object id stored in a lightweight tag ref, with loose/packed/missing-tag regression coverage and help/docs updates.
- Added `version diff --cached` as a byte-identical alias for existing staged diff output (`version diff --staged`), with help/docs and regression coverage.
- Added `version status --short` as a byte-identical alias for the stable project-specific `version status --porcelain` subset, with help/docs and regression coverage.
- Added read-only `version branch current` support for direct attached-branch inspection, with stable help/docs and detached-HEAD rejection coverage.
- Added `version remote set-url NAME URL` support for updating an existing remote URL, with docs/help coverage and regression tests for preserving fetch refspecs, missing-remote rejection, and no accidental remote creation.
- Added read-only `version remote get-url NAME` support for direct remote URL lookup, with stable help/docs and regression coverage for URL-only output, missing remotes, and no-mutation behavior.
- Added quiet read-only `version config has KEY` support for config key-existence checks, with stable help/docs and no-mutation regression coverage.
- Added read-only `version config get KEY` support for direct local config value lookup, with stable help/docs and config lookup regression coverage.

- Added stable read-only `version remote list` output and tests for tab-separated `name<TAB>url` rows.

### Phase 43 documentation edge-case examples pass
- Cleaned up command documentation spacing before the `version doctor` section.

- Added `docs/EDGE_CASE_EXAMPLES.md` with release-facing examples for restore/submodule gitlink boundaries, archive unsafe path rejection and output preservation, SHA-256 unsupported-format rejection, post-commit no-rollback behavior, transport failure no-mutation guarantees, and platform CI evidence validation.
- Wired documentation coherence and test-scope gates to require the release edge-case examples so future release-polish edits do not drop them.

## Phase 43 - Status branch summary mode

- Added `version status --branch` for a stable branch-header status view that prepends `## branch`, includes upstream/ahead/behind details when configured, and then emits the same short status entries as the project-specific porcelain subset.
- Added help, documentation, and regression coverage for the branch status mode while leaving normal, porcelain, and short status output unchanged.

## Phase 43 - Worktree list/status display polish
- Added `tools/bin/summarize_release_evidence` to produce a release-facing POSIX/Windows CI evidence summary after evidence validation.

- Added stable labelled `version worktree list` output for primary/current, linked branch-in-use, missing linked paths, and detached linked worktrees.
- Added testable worktree status formatting helpers and regression coverage for missing linked worktree metadata visibility.
- Updated command, usage, testing, worktree, and release documentation for the worktree list markers.

## Phase 43 - CLI status porcelain subset

## Phase 43 - Submodule status display polish

- Added stable labelled `version submodule status` output for clean, missing, advanced, and dirty submodule states.
- Added testable submodule status formatting helpers and CLI-facing regression coverage for the display contract.
- Updated command, usage, testing, and release documentation for the submodule status markers and labels.

- Added `version status --porcelain` as a stable project-specific machine-readable status subset.
- Added `version status --short` as a byte-identical alias for that subset.
- Added CLI freeze tests and documentation for staged (`S`), working-tree (`W`), and untracked (`?`) porcelain records.

## Phase 43 - General completeness pass
- Added centralized command-unavailable diagnostics and CLI freeze tests for missing repository, remote/upstream, sparse, linked-worktree, and unsupported-format preconditions.

- Added consistent CLI help/version affordance coverage for `version -h`, `version COMMAND --help`, `version COMMAND -h`, and centralized `version --version` output.
- Added `tools/bin/check_documentation_coherence` and wired it into release consistency/package gates so stale diagnostics, malformed release notes, and missing release-gate documentation are caught.
- Cleaned README release-gate examples into copy-pasteable shell blocks.
- Rewrote release notes into a coherent release-facing baseline plus Phase 43 stabilization summary.
- Replaced stale internal HTTP helper diagnostics that still said `the old HTTP not-implemented wording` with precise smart-transport/local-git-dir wording.

## Phase 43 - Command-boundary corruption second-pass coverage

- Added `tools/bin/check_test_scope_completeness`, a release gate that verifies Phase 43 release-critical test suites remain present, registered, documented, and above the closure routine-count floor.
- Expanded command-boundary corruption fixtures for stage, save, log, branch-switch corrupt blobs, archive corrupt blobs, and malformed/corrupt submodule configuration boundaries.
- Added no-mutation assertions that failed stage/save preserve corrupt index bytes, dirty working-tree content, branch refs, and reflogs.
- Added corrupt-blob checkout/archive boundaries proving failed checkout does not materialize partial files and failed archive preserves preexisting output.

## Phase 43 - Release stabilization test-suite expansion

- Expanded CLI golden-output freeze coverage for clone, fetch, push, archive, submodule, worktree, sparse, and command-boundary corruption diagnostics; added testable help text for the advanced command set.


## Phase 43 - Hook late-failure edge coverage

- Added `tools/bin/check_release_package_selftest` with negative release-package fixtures for forbidden build artifacts, nested generated archives, missing required release files, and missing platform CI gates.
- Hardened release package validation to require `docs/RELEASE_NOTES.md` and the package self-test script in source archives.
- Expanded hook semantics coverage for no-op saves, object-storage failures before commit completion, frozen hook failure diagnostics, and rebase-continuation post-commit failures.
- Hardened `version save` so an unchanged index tree is a true no-op: it does not create a replacement commit and does not run commit hooks.
- Added rebase continuation coverage proving a failing `post-commit` is reported after the continuation commit remains Git-readable and the completed rebase state is not rolled back.


## Phase 43 - Rebase Git compatibility acceptance coverage

- Expanded the Git compatibility acceptance suite with rebase-continuation workflows validated by the system `git` command.
- Added checks that `git fsck --strict`, `git log`, `git status --porcelain`, and `git checkout` can read repository state after a Version conflict rebase is resolved through `Version.Rebase.Continue_Rebase`.
- The acceptance fixtures now prove Version-created rebase continuation commits keep Git-readable parentage, clean status, and resolved working-tree content.


## Phase 43 - Cross-feature interaction matrix coverage

- Added a dedicated cross-feature regression suite covering sparse restore with submodule gitlink boundaries, sparse-excluded submodule restore no-mutation behavior, linked-worktree submodule restore isolation from the primary worktree, linked-worktree `post-commit` root/environment semantics, archive sparse-checkout independence with gitlink placeholders, and corrupt shallow fetch preservation of both existing refs and `.git/shallow`.

# Changelog


- Added quiet `version remote exists NAME` support for script-friendly remote existence checks, with help/docs coverage and tests for present, missing, invalid, and read-only behavior.

### Phase 43 ref transaction evidence contract

- Added `tools/bin/check_ref_transaction_selftest` as a release-facing smoke test for expected-old ref transaction behavior.
- Updated platform CI evidence to require `ref_transaction=passed` alongside `ref_write_policy=passed`, with verifier, summarizer, selftest, and release consistency coverage.

### Phase 43 platform CI evidence pass

- Added `tools/bin/check_platform_ci_evidence` so POSIX and Windows platform gate results can be verified as release evidence for the same source tree.
- Updated POSIX/Windows platform gates to emit evidence files when `VERSION_PLATFORM_CI_EVIDENCE_DIR` is set.
- Updated the copy-ready CI matrix to upload POSIX/Windows evidence and verify it in a dependent job.

### Phase 43 platform CI confirmation pass

- Added POSIX and Windows platform CI gate scripts so platform-sensitive tests are confirmed on real hosts rather than only by simulated path-policy fixtures.
- Added a copy-ready GitHub Actions platform matrix template under `ci/`.
- Added CI documentation and documentation tests requiring the platform gates to remain present.


## Phase 43 - Command-boundary corruption coverage

- Added command-boundary corruption tests for status, restore, branch switch, archive export, and fetch.
- Status now has regression coverage proving corrupt index rejection does not rewrite the index or mutate working-tree sentinels.
- Restore, branch switch, and archive now have raw corrupt-tree command-boundary fixtures proving failure preserves working-tree files, HEAD/current branch state, and preexisting archive outputs.
- Fetch now has a local-remote fixture proving a corrupt local object for an advertised remote commit is rejected before rewriting an existing remote-tracking ref.

## Phase 43 - CLI golden-output freeze breadth

- Added testable CLI output formatting helpers for stable `error:` diagnostics, expected-usage diagnostics, and unknown-command diagnostics.
- Added testable help/status output fragments so release-critical help, status clean/dirty lines, unsupported-format diagnostics, corruption/transport/hook failure prefixes, and redaction expectations are frozen without brittle full-process captures.
- Expanded CLI tests to cover top-level help, selected command help, missing operand output, unknown command output, status clean/dirty fragments, unsupported SHA-256 output, branch-switch failure output, corruption output, transport failure output, and hook failure output.

## Phase 43 - SHA-256 command-level unsupported-format coverage

- Added command-level SHA-256 unsupported repository tests for status, stage, restore, save, and fetch, each asserting stable unsupported-format rejection before command mutation.
- Added no-mutation assertions for index, working-tree contents, branch refs, HEAD reflog, and existing remote-tracking refs after SHA-256 command rejection.
- Introduced `Version.Stage.Stage_Path` as a testable staging command seam and routed the CLI stage implementation through it.

## Phase 43 - Git compatibility end-to-end matrix

- Added a dedicated Git compatibility acceptance suite covering Git-readable Version save/amend commits, clean Git status after Version restore/stage/branch-switch flows, Git checkout of Version-created history, Git fsck/log validation after Version revert and cherry-pick commits, Git archive of Version-created trees, Git submodule status over Version-created gitlinks, and tar extraction of Version-created archives.

## Phase 43 - Archive release-safety second-pass expansion

- Expanded archive release-safety coverage for failed exports preserving preexisting output archives, removing same-directory temporary archive outputs, rejecting unsafe symlink targets read from committed object data, and rejecting unsupported tree file modes without leaving output artifacts.
- Hardened archive export to write TAR/ZIP data to a same-directory temporary file and atomically replace the requested output only after successful archive completion, preventing failed exports from clobbering an existing archive.

## Phase 43 - Push failure mutation-safety matrix expansion

- Expanded fetch-ingestion corruption coverage so bad pack checksums, missing delta bases, and advertised-object mismatches received from HTTP upload-pack fail without updating or creating remote-tracking refs and without leaving temporary pack/index artifacts.
- Expanded push failure coverage across HTTP receive-pack network drop, remote unpack error, non-fast-forward report-status rejection, partial report-status, local non-fast-forward rejection, and conflicting tag rejection.
- Added assertions that failed pushes preserve existing remote-tracking refs/local tracking assumptions, leave working-tree sentinels unchanged, and remove temporary push pack/index artifacts across failure modes.

## Phase 43 - Transport existing-ref preservation coverage

- Expanded failed-fetch transport mutation-safety coverage so malformed pkt-line, truncated pack, upload-pack fatal, unknown sideband, missing-object/empty-pack, HTTP discovery failure, shallow capability/fatal, and SSH backend failures preserve an already-existing `refs/remotes/origin/main` value byte-for-byte.
- Added shallow failure assertions that existing remote-tracking refs and existing `.git/shallow` metadata are preserved together when depth negotiation fails.

## Phase 43 - Restore/submodule gitlink interaction second-pass coverage

- Expanded restore/submodule regression coverage for source-missing gitlinks, staged removal of source-missing gitlink entries without deleting submodule worktrees, direct gitlink path restores, and ordinary-file conflicts at gitlink paths.
- Hardened restore so gitlinks are treated as submodule directory boundaries: existing submodule directories are allowed, ordinary files at gitlink paths are rejected before mutation, and working-tree-only directory restores do not remove source-missing submodule worktrees.

## Phase 43 - Archive release-safety coverage expansion

- Expanded archive release-safety coverage for hostile object-database tree entries, documented TAR/ZIP gitlink placeholder behavior, stable unsupported archive-output diagnostics, partial-output cleanup on failed archive export, and repeated TAR/ZIP entry-order determinism.
- Hardened archive export cleanup so TAR/ZIP failures remove the partially written output file before re-raising the archive error.

## Phase 43 - Restore/submodule gitlink interaction coverage

- Added restore regression coverage proving directory restore preserves gitlink entries, restores ordinary parent files without recursing into submodule worktrees, staged directory restore preserves gitlink mode/object ids, and dirty submodule worktree files are not overwritten by parent restores.

## Phase 43 - Submodule URL edge-case second-pass expansion

- Expanded relative submodule URL edge coverage for backslash separators, backslash traversal rejection, duplicate/empty relative URL components, control-character rejection, SSH remotes with explicit ports, and absolute URL preservation.
- Added additional `.gitmodules` malicious-path regressions for nested traversal, duplicate separators, Windows drive paths, and backslash traversal.
- Hardened relative submodule URL handling so backslash separators are normalized before relative detection/resolution and empty relative URL components are rejected before clone/update mutation.

- Expanded object and pack corruption coverage: corrupt loose zlib streams, missing loose-object headers, declared-size mismatches, loose-object hash mismatches, malformed tree entries, missing/invalid commit tree headers, truncated packs, bad pack checksums, missing ref-delta bases, and truncated pack indexes are now tested for deterministic rejection without leaving generated indexes.
- Hardened object/pack readers so loose objects verify declared size and object id hash, and pack indexing verifies the pack trailer checksum before writing an index.

## Phase 43 - Submodule URL edge-case test expansion

- Expanded relative submodule URL resolver coverage for HTTPS/SSH/scp-like bases without `.git`, HTTPS bases with trailing slashes, `./../` normalization, excessive traversal rejection across HTTPS/SSH/file/local bases, and malformed or empty base remotes.
- Added `.gitmodules` malicious-path regression coverage for escaping, absolute, and `.git/hooks` submodule paths.
- Hardened relative URL resolution so trailing slashes on superproject remotes are normalized before resolving and excessive `..` traversal is rejected consistently for URL and local-path bases.

## Phase 43 - Platform-specific test expansion

- Expanded portable Windows path-policy tests for drive-root, drive-relative, UNC, slash-absolute, reserved-device, and backslash traversal forms.
- Added POSIX filesystem-guard regressions proving symlink parent/write/delete/preflight paths are rejected without materializing or deleting through the symlink.
- Added a POSIX permission-denied atomic-write regression that preserves the original file and removes temporary state when the host permission model enforces the fixture.

## Phase 43 - Hostile tree/path test expansion

- Expanded hostile path validation tests for nested traversal, literal `.git` entries, `.git/hooks` entries, empty path components, trailing slashes, Windows drive paths, and backslash traversal.
- Added hostile raw-tree restore fixtures for nested traversal, literal `.git`, `.git/hooks/post-checkout`, empty path components, and trailing slash entries, with explicit no-mutation assertions for existing working-tree files.
- Added hostile archive tree-entry rejection coverage so archive export refuses unsafe object paths before leaving an output archive.
- Hardened repository-relative path normalization so duplicate separators are rejected as empty path components instead of silently collapsing.

## Phase 43 - Hook execution semantics expansion

- Added second-pass hook semantics tests for commit-msg-blocked post-commit suppression, `VERSION_NO_HOOKS` post-commit suppression, absolute hook-name rejection, and symlinked POSIX hook no-op behavior.
- Hardened hook executability checks so symlinked hook files are ignored instead of following targets that may escape `.git/hooks`.
- Added post-commit timing and environment coverage proving the hook observes the updated HEAD, runs from the repository root, receives `GIT_WORK_TREE`, and is skipped when commit creation is blocked before mutation.
- Added hook execution contract tests for stable empty result-output capture and POSIX non-executable hook no-op behavior.
- Changed `Run_Post_Commit` to report non-zero post-commit exits to the caller after the commit/ref/reflog update has completed, preserving the documented no-rollback behavior while surfacing hook failure.

## Phase 43 - Transport mutation-safety matrix expansion

- Expanded transport failure regression coverage into a mutation-safety matrix for malformed upload-pack pkt-lines, truncated packs, upload-pack fatal sideband packets, unknown sideband channels, empty/missing-object pack responses, HTTP discovery failure, shallow capability/fatal failures, SSH backend failure, and HTTP receive-pack report-status rejection.
- Hardened failed HTTP fetch handling so refs are not updated unless the requested commit object is actually present and readable after pack ingestion.
- Kept failed fetch/push cleanup assertions explicit for remote-tracking refs, temporary packs/indexes, working-tree sentinels, and existing `.git/shallow` metadata.


## Phase 43 - Highest-value test suite expansion

- Expanded relative submodule URL regression coverage with testable resolver assertions for HTTPS, SSH, scp-like SSH, deeper legal traversal, and scp-like escape rejection.
- Added restore interaction tests for sparse-excluded directory restores, trailing-slash directory prefixes, and linked-worktree restore isolation.
- Froze test-visible CLI usage/failure exit statuses and added CLI error-prefix payload coverage.
- Added hostile tree entry fixtures for `.git` and absolute paths.
- Added fetch failure mutation-safety coverage proving missing local remotes do not create remote-tracking refs.

## Phase 43 - Small compatibility and freeze consistency

- Documented `post-commit` as part of the frozen supported hook allow-list and aligned hook/security/compatibility docs.
- Added `tools/bin/check_release_consistency` and wired it into release/package documentation to catch command, hook, archive, and unsupported-scope drift.
- Implemented tracked directory restore expansion for working-tree and staged restore paths while leaving unrelated untracked files untouched.
- Added relative submodule URL resolution for common `./` and `../` forms against the configured superproject remote URL.

## Phase 42 release stabilization completeness pass 3

- Added a testable CLI error-normalization seam so expected user errors preserve actionable diagnostics while internal `Constraint_Error`/`Program_Error` failures are rendered as `internal command error` instead of leaking raw Ada exception names.
- Added CLI regression tests for the release error-reporting policy and extended the release-freeze documentation check to require the normalized internal-error text.


## Phase 42 release stabilization completeness pass 2

- Expanded the release checklist so every Phase 42 required smoke workflow is explicitly frozen: init/stage/save/fsck, local clone branch switching, local fetch/push, TAR/ZIP archive export, restore/checkout paths, replay conflict workflows, worktree add/remove, and submodule update.
- Added documentation regression coverage that checks the release checklist names each required release smoke workflow and repeats the no-public-internet requirement.
- Added an explicit release error-reporting policy requiring expected user/repository/transport/hook failures to avoid raw Ada exception traces or implementation dumps.
- Tightened release-package artifact rejection for Alire local state and native binary/library outputs such as `.exe`, `.dll`, `.so`, `.a`, and `.dylib`.

## Phase 42 release stabilization pass 1 (0.1.0-dev)

- Added `docs/RELEASE_FREEZE.md` to freeze the 1.0 command surface, exit-code policy, repository-format limits, transport limits, archive behavior, hook behavior, Windows limitations, and packaging policy.
- Hardened `tools/bin/check_release_package` so it accepts both flat and root-prefixed release archives while rejecting generated artifacts, local VCS/build directories, scratch outputs, temporary archives, and root `alire.toml` parent-directory pins.
- Added release-critical regression coverage for exact binary-file round-trip through Version-created commits and for required release-freeze documentation.

## Phase 41 scalability completeness pass 21

- Optimized shallow-boundary normalization and fetch shallow-update merging.
- `.git/shallow` read/write normalization now deduplicates through command-local ordered sets instead of repeated vector membership scans.
- Smart-HTTP shallow/unshallow response application now builds ordered sets for existing and unshallow ids, avoiding nested scans while preserving deterministic shallow-file output.


- Continued Phase 41 maintenance loose-object scalability by tracking discovered loose object IDs in a command-local ordered set while scanning `.git/objects`, avoiding repeated vector membership scans during prune/verify object discovery.
- Continued Phase 41 replay/stash scalability by routing cherry-pick, revert, rebase replay, and stash apply merge setup through command-local object/tree caches; these flows now reuse commit reads, tree flattening, and restore/index materialization within one replay/apply operation.
- Continued Phase 41 checkout/restore scalability by exposing cache-aware restore entry points and routing full commit checkout plus path checkout through shared command-local object/tree caches, so checkout no longer re-reads the target commit or re-flattens the target tree between working-tree and index materialization.
- Continued Phase 41 branch/integration scalability by routing merge-tree setup and integration-abort cleanup through command-local object/tree caches, and by replacing target-only cleanup path membership scans with an ordered path set.
- Continued Phase 41 branch-tracking scalability by replacing ahead/behind reachable-commit vector membership with command-local ordered object-id sets, adding command-local object and shallow-boundary caches to tracking walks, and adding divergent ahead/behind regression coverage.
- Continued Phase 41 shallow-history scalability by adding `Version.Shallow_Cache`; log, history, maintenance verification, prune filtering, and reachability traversal now load `.git/shallow` once per command-local cache instead of rereading it during each commit/object boundary check.
- Continued Phase 41 history scalability by replacing ancestry, merge-base, and reachable-object traversal vector-membership scans with command-local ordered object-id sets and by routing commit/tree reads through a command-local object cache, with reachable-object regression coverage for commit traversal.
- Continued Phase 41 restore/checkout scalability by routing restore/index materialization commit/tree reads through command-local object/tree caches and replacing index-vs-tree deletion checks with an ordered tree path map, preserving safe preflight and sparse semantics.
- Continued Phase 41 ordering scalability by replacing quadratic bubble/selection sorts in status change lists, diff side vectors, staging index entries, and shallow object-id writes with Ada container generic sorting while preserving deterministic path/object ordering.
- Continued Phase 41 diff/pathspec scalability by routing working-tree diffs through the pathspec-aware working-tree scan, loading ignore/tracked-path context once, and replacing tracked-working matching with an ordered map instead of per-index-entry linear searches.
- Continued Phase 41 status/pathspec scalability by adding a pathspec-aware working-tree scan; path-filtered status still traverses conservatively for correctness, but non-matching ordinary files and gitlinks are no longer hashed or appended before final status filtering.
- Continued Phase 41 archive scalability by caching selected archive entries once per export, de-duplicating explicit parent directories through an ordered set, and tracking ZIP entry names through an ordered set instead of repeatedly scanning central-directory metadata for duplicate checks.
- Continued Phase 41 maintenance/reachability scalability by replacing traversal membership checks with command-local ordered object-id sets, using set membership for prune unreachable filtering, verifying repack output through a freshly loaded pack-index cache instead of repeated pack index scans, and adding a duplicate-root reachability regression.
- Continued Phase 41 push scalability by adding a file-backed receive-pack request builder; HTTP push now reads the generated pack directly into the final request buffer instead of first materializing a separate whole-pack byte array and then copying it into a second whole-request buffer.
- Continued Phase 41 pack scalability by making `Version.Pack_Write` stream PACK bytes directly to disk while maintaining an incremental SHA-1 trailer and using command-local object-cache reads during pack generation; this avoids retaining the complete pack body in memory before writing.
- Added incremental SHA-1 support (`Sha1_Context`, `Update`, `Final_Hex`, `Final_Raw`) with block-boundary regression tests so streaming pack and future transport paths can checksum data without whole-buffer hashing.
- Continued Phase 41 scalability hardening by replacing diff side/path lookups with ordered maps, so diff classification no longer performs repeated linear searches across old/new path sides.
- Indexed tracked working-tree paths, gitlinks, and tracked directory prefixes during scans so ignored-directory pruning and tracked-file exceptions do not repeatedly scan the whole index.
- Added command-local cache count accessors for object, tree, and pack-index caches, plus a non-timing regression check that repeated object/tree reads stay bounded in the cache.
- Streamed HTTP fetch upload-pack responses directly through pkt-line/side-band demux into the temporary pack file, avoiding whole-response and whole-pack buffering before `Index_Pack`.
- Started Phase 41 large-repository scalability work by adding `Version.Pack_Index_Cache`, exposing cached pack locations to `Version.Object_Cache`, and adding regression coverage for cached packed-object lookup without changing repository semantics.
- Extended the Phase 41 cache path so revision abbreviation resolution checks packed objects through the command-local pack-index cache, archive generation reuses command-local object/tree caches, and maintenance/reachability traversal reuses command-local object/tree reads during verification.
- Added optional Phase 41 benchmark tool entry points for status, log, archive, and object lookup diagnostics; these tools are excluded from normal unit-test pass/fail timing criteria.
- Strengthened archive completeness coverage for branch revisions, sparse-checkout independence, gitlink placeholders, symlink metadata preservation, explicit TAR/ZIP directory entries, unsupported tree file-mode rejection, archive usage validation before repository open, control-character rejection for archive names and symlink targets, empty output rejection, extracted binary-byte checks, empty ZIP entries, no-match archives, exclusion pathspecs, long TAR paths, case-insensitive unsupported compressed output rejection, and stricter archive path/file-entry and symlink-target validation, plus duplicate archive entry-name rejection.
## Phase 39 - Documentation and examples

* Expanded README with status, build/test instructions, quick start, supported command summary, compatibility promise, limitations, and documentation map.
* Added or refreshed command, architecture, compatibility, repository-format, transport, security, portability, maintenance, worktree, submodule, hook, and release-checklist documentation.
* Added deterministic examples for basic use, local remotes, HTTP remotes, SSH remotes, worktrees, and submodules.
* Added `tools/bin/check_examples` as a lightweight smoke checker for local deterministic examples.
* Kept Phase 39 documentation-only; no repository feature behavior changed.

## Phase 38 - Windows portability hardening

* Centralized portability-sensitive recursive directory deletion in `Version.Files.Delete_Directory_Tree_If_Exists`.
* Hardened working-tree scan path normalization for native Windows separators.
* Enforced Windows-safe filesystem component policy for branch, tag, remote, and remote-tracking ref names.
* Hardened atomic replacement source validation, case-collision diagnostics, drive-relative submodule URL classification, and platform path helper usage.

## Phase 37 - Filesystem guard hardening

* Added guarded preflight for checkout, restore, branch switch, clone checkout, sparse mutation, submodule materialization, remove, and stash restoration paths.
* Centralized safe write/delete validation and collision checks before user-tree mutation.

## Phase 35 - Client-side hook support

* Added practical client-side hook support for `pre-commit`, `commit-msg`, `post-checkout`, and `pre-push`.
* Added `--no-verify` support for save and push paths that run blocking hooks.


## Phase 40 - Archive export

Added repository archive creation through `version archive`, with TAR and ZIP writers, revision/tree-based export, pathspec filtering, deterministic metadata, and safe submodule gitlink placeholders. Archive output is generated from committed objects rather than the working tree or index.

- Phase 40 archive support now supports safe `--prefix DIR/` root rewriting for TAR and ZIP output and rejects unsafe archive prefixes.

### Phase 41 completeness pass 15

- Added packed-ref storage to the command-local `Version.Ref_Cache`, so packed refs are loaded once per command cache and then served from an ordered map.
- Added `Version.Ref_Cache.Try_Resolve_Ref` plus diagnostic accessors for resolved refs and packed-ref cache state.
- Updated revision-name resolution to use the command-local ref cache directly, avoiding repeated `packed-refs` parsing across `refs/heads/`, `refs/tags/`, `refs/remotes/`, and fully-qualified ref probes.
- Added regression coverage proving packed refs are loaded once, remain stable until `Clear`, and reload after explicit cache clearing.
- Added sparse-index `sdir` read expansion with desparsifying writes for mutating index commands; unsupported-feature diagnostics remain frozen for SHA-256 repositories, promisor sidecars without a configured partial-clone remote, HTTP/3/h2c/server-push capability gaps, unsupported remote URLs, and SSH streaming limitations.
- Added CLI tests that freeze the unsupported-feature diagnostic contract.
- Added `version doctor` and `version doctor --release` convenience commands for non-mutating repository health checks and source-tree release-gate preflight.

- Phase 43 archive UX polish: added explicit unsupported-format suggestions and component-specific unsafe-prefix diagnostics.

- Added read-only `version config list` command with stable `section.key=value` output and tests.
