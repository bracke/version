# Release notes: 0.1.0-dev
This is a release-stabilization baseline for the Ada `version` CLI after the core repository, branch, object, ref, transport, restore, ignore, status/diff/log/show, revision, maintenance, security, portability, HTTP, SSH, archive, worktree, submodule, hook, sparse-checkout, and release-test foundations have landed.

## Highlights

* Git-compatible `.git` storage for supported workflows.
* Native init, staging, save, amend, restore, checkout, status, diff, log, show, common pathspec filtering, branches, tags, remotes, fetch, clone, push, linear rebase, cherry-pick, revert, stash, packed refs, reflogs, pack read/write, and maintenance foundations. POSIX checkout/restore now materializes committed symlink entries; stash push/create supports pathspec-limited tracked/untracked/ignored saves; stash store can place stash-shaped commits on the stack with subject-derived default list messages and optional overrides; stash show/apply/pop support pathspec filtering, no-match CLI feedback, and selected apply preflighting writes before mutation; stash clear removes the full stash stack; and stash branch can create a branch from a selected stash base.
* Local and `file://` transport support.
* Smart HTTP(S) support through `HttpClient`, including HTTPS HTTP/2 ALPN with HTTP/1.1 fallback for streaming Git requests.
* SSH transport uses the native `ssh_lib` library (no external `ssh` binary): URL parsing builds the remote command and `git-upload-pack`/`git-receive-pack` run over an `ssh_lib` exec channel, with `~/.ssh/config` resolution (HostName/Port/User/IdentityFile/known_hosts), host-key verification, identity files, and agent handled by `ssh_lib`. SSH fetch, clone, and push are available through upload-pack/receive-pack workflows, including depth-limited SSH fetch/clone negotiation when the server advertises shallow support and annotated tag following when upload-pack advertises `include-tag`. Branch push supports `--force` for non-fast-forward updates; `version push --tags` works over local, `file://`, HTTP(S), and SSH remotes (refusing to overwrite a differing remote tag).
* Deterministic release tests and public-internet-free verification path, including `tools/bin/check_ref_write_policy_selftest` and `tools/bin/check_ref_transaction_selftest` for low-level ref mutation safety, plus platform evidence for the ref-write-policy and ref-transaction gates.
* TAR and ZIP archive export from committed objects with deterministic entry ordering and safe gitlink placeholders.
* Release-facing test gates for package cleanliness, documentation coherence, test-scope closure, and POSIX/Windows platform CI evidence.

## Phase 43 release-stabilization updates

Phase 43 focused on broadening release safety and test completeness rather than adding new end-user workflows.

* CLI behavior is frozen through golden-output fragments for help, usage, status, submodule status labels, worktree list/current markers, sparse status output, unsupported-format, transport, hook, archive, submodule, worktree, sparse, remote, and corruption diagnostics.
* `version remote list` output is now a stable read-only tab-separated `name<TAB>url` surface.
* `version remote get-url NAME` prints a single configured remote URL without mutating repository configuration.
* `version remote exists NAME` is a quiet predicate that reports remote existence through exit status without mutating repository configuration.
* `version remote set-url NAME URL` updates an existing remote URL while preserving the remote fetch refspec.
* `version remote rename OLD NEW` renames an existing remote while preserving its URL and existing fetch refspec. `version remote prune NAME --dry-run` reports stale remote-tracking refs as `would prune NAME/BRANCH` lines without deleting them; `version remote prune NAME` deletes stale remote-tracking refs and reports `pruned NAME/BRANCH` lines. SSH remotes now use upload-pack advertised-ref discovery for prune, with failed discovery preserving existing remote-tracking refs.
* `version branch current` prints the attached branch name as a small read-only branch-inspection porcelain command.
* `version branch exists NAME` is a quiet read-only predicate for branch existence, matching the existing config/tag/remote predicate style.
* `version branch resolve NAME` prints the branch tip object id as a small read-only branch-inspection command.
* `version branch upstream [BRANCH]` prints the configured upstream as `remote/branch`, defaulting to the current branch when BRANCH is omitted.
* `version branch contains REV` lists sorted branch names whose tips contain the resolved commit, without mutating refs, the index, or the working tree.
* `version branch merged [BRANCH]` lists sorted branches whose tips are ancestors of the current or named branch tip, without mutating repository state.
* `version branch unmerged [BRANCH]` lists sorted branches whose tips are not ancestors of the current or named branch tip, without mutating repository state.
* SHA-256 object-format repositories are supported: `init --object-format=sha256` creates them, and they are read and written (local and smart HTTP/SSH transport, format negotiated via the `object-format=sha256` capability), byte-compatible with system git.
* Hook behavior now covers post-commit timing, working directory, disabled hooks, non-executable/symlink policy, no-op saves, late commit failures, and replay/rebase continuation failure behavior.
* Restore, archive, and submodule handling now include extensive gitlink, sparse-checkout, linked-worktree, hostile-path, and no-mutation coverage.
* Transport tests now cover failed fetch/push mutation safety, existing-ref preservation, stale local push branch/tag detection and expected-old final writes, receive-pack remote-tracking expected-old protection, fetch remote-tracking expected-old protection, shallow metadata preservation, corrupted fetch ingestion, malformed protocol streams, and push report-status failures.
* Atomic file replacement now documents the normal `Version.Files.Atomic_Replace` API separately from the `Version.Files.Rollback` backup-rollback fallback surface, including rollback backup path naming for regression coverage and diagnostics.
* Object, pack, fetch-ingestion, and command-boundary corruption cases are tested for deterministic rejection and no partial output/repository mutation.
* Git compatibility acceptance tests use the system `git` command for Version-created save/amend/rebase/revert/cherry-pick/archive/submodule states.
* Platform-sensitive behavior is backed by POSIX and Windows CI gate scripts plus a release-evidence checker.
* Release evidence can be summarized with `tools/bin/summarize_release_evidence` after POSIX/Windows evidence validation.
* Platform evidence now requires `ref_transaction=passed` alongside `ref_write_policy=passed`; release consistency checks guard that marker across the platform matrix, evidence verifier, summarizer, selftest fixtures, and release documentation.
* Release package validation now includes negative package-shape self-tests and documentation-coherence checks.

## Archive export

`version archive` creates deterministic source snapshots from committed repository objects, not from the working tree or index. TAR and ZIP preserve committed bytes, CRLF text, binary payloads, executable metadata where supported, symlink metadata, explicit directories, and safe submodule gitlink placeholders. ZIP entries are emitted through the integrated Ada Zlib stored-deflate path.

Archive output is written through a same-directory temporary file and replaces the requested output only after successful completion. Failed exports remove temporary output and preserve any preexisting archive. Unsafe entry names, unsafe prefixes, control-character names, unsafe symlink targets, duplicate entry names, directory/file collisions, unsupported tree file modes, and compressed/proprietary archive suffixes outside TAR/ZIP are rejected.

## Compatibility scope

See `docs/COMPATIBILITY.md` for the detailed matrix. Notable unsupported or intentionally narrow areas are reftable ref storage, advanced submodule workflows, advanced worktree administrative parity, advanced Git pathspec magic beyond basic attrs (such as icase/from-file), HTTP/3 and h2c transports, SMTP `send-email`, and proprietary archive formats (xz/bzip2/7z/rar). SHA-256 object format, root/interactive/merge-preserving rebase (incl. resumable `--rebase-merges` conflicts), credential helpers, and compressed `tar.gz` archives are now supported.

## Upgrade notes

No repository conversion is required for supported workflows. Repositories remain normal Git repositories within the documented SHA-1 Git-compatible scope.
Phase 43 also adds `version doctor` and `version doctor --release` as small CLI affordances for local repository health checks and source-tree release-gate preflight.


Phase 43 also centralizes command-unavailable diagnostics so common precondition failures are reported with precise, stable messages before mutation.

- Phase 43 also freezes the project-specific `version status --porcelain` machine-readable subset and the byte-identical `version status --short` alias. It also adds `version diff --cached` as a byte-identical alias for `version diff --staged`, and read-only `version tag list --points-at REV` for exact lightweight-tag/ref matching, read-only `version tag list --contains REV` for tag reachability queries, read-only `version tag exists NAME` for quiet tag-existence checks, read-only `version tag resolve NAME` for printing the object id stored in a lightweight tag ref, read-only `version tag show NAME` for stable lightweight and annotated tag inspection, read-only `version tag peel NAME` for peeled target ids, explicit tag target creation with `version tag create NAME REV` and `version tag create -a NAME REV -m MESSAGE`, ref-level tag rename with `version tag rename OLD NEW`, and `version log --oneline` for compact `<short-id> <subject>` commit history output.

- Archive UX diagnostics now suggest supported TAR/ZIP formats and identify unsafe prefix components. Branch, tag, stash, save/amend, rebase, cherry-pick, and revert ref movements now route through expected-old ref transactions where applicable, and detached HEAD save/cherry-pick/revert writes require the previously observed HEAD id, while local-path push branch/tag writes re-check the remote ref immediately before the final write and commit the final ref movement through expected-old transactions; receive-pack remote-tracking updates require the previously observed local tracking id; fetch stages advertised remote-tracking and tag updates with the current local ref id as expected-old.


## Release edge-case examples

`docs/EDGE_CASE_EXAMPLES.md` gives copyable examples for the hardened edge cases that define the Phase 43 release contract: restore/submodule boundaries, archive unsafe path rejection, unsupported-format handling (e.g. reftable refs), hook no-rollback behavior, transport failure no-mutation guarantees, and platform CI evidence validation.

* Added `version config list`, `version config keys`, `version config get KEY`, quiet `version config has KEY`, `version config set KEY VALUE`, and `version config unset KEY` support for stable local repository config inspection and narrow local key mutation.

* Phase 43 also adds `version branch list --verbose` for short tip-id/subject branch inspection, `version status --branch` for a stable branch-header status view, and compatibility aliases `version branch list --contains REV`, `version branch list --merged [BRANCH]`, and `version branch list --no-merged [BRANCH]` for the existing branch reachability queries.
