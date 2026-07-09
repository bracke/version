- Git parity: matching push — `push REMOTE :` (and a bare `push REMOTE` when `push.default=matching`) updates every remote branch that shares a name with a local branch, creating no new remote branches (`Version.Push.Push_Matching`). The remote's branch list is discovered per transport: a local repo scan, or the receive-pack ref advertisement over HTTP/SSH (`Version.Receive_Pack.Discover_Http`/`Discover_Ssh`). Verified against git (local + `git-http-backend`): matching branches update, a local-only branch is not created.
- Git parity: `push --atomic` (local, HTTP, SSH) — all ref updates/deletes in one invocation are applied all-or-nothing. Over smart transports they go in a single receive-pack request advertising the `atomic` capability (`Version.Receive_Pack.Push_Atomic`/`Push_Atomic_Ssh`: batched command pkt-lines + one union pack + batched report-status); local pushes apply every update in one `Ref_Transaction` (`Version.Push.Push_Atomic`). Non-fast-forward updates (unless `--force`) are rejected before anything is applied, so the remote is left untouched; the push also errors if the remote does not advertise `atomic`. Verified against real git (`git-http-backend`) for batched success and all-or-nothing rejection. `--atomic --tags` is rejected (use explicit refspecs).
- Git parity: `clone <bundle>` — a local plain-file clone source is now unpacked as a git bundle (`Version.Clone.Clone_From_Bundle`): the packfile is written to the object store, the bundle's refs become `refs/remotes/origin/*` (tags copied as-is), `origin` is set to the bundle path, and the default branch is checked out (git's `guess_remote_head` order: main/master carrying HEAD's id, else the branch matching HEAD's id, else main/master/first). Object format follows the bundle's ref-id width. Incomplete (prerequisite) bundles are rejected. Verified against git both directions, `fsck`-clean.
- Git parity: leading-colon revision syntax — `:path` and `:<stage>:path` resolve to the blob recorded in the index (stage 0 by default; conflict stages 1/2/3 supported), and `:/<regex>` resolves to the youngest commit reachable from any ref (and HEAD) whose log message matches the POSIX regular expression. Wired into `Version.Revisions.Resolve`, so `rev-parse`/`cat-file`/`show` accept them. Verified against git for index blobs, all-refs message search (including a commit only on a non-HEAD branch), and error cases.
- Git parity: `log --show-signature` — interleaves gpg's own verification lines (e.g. `gpg: Good signature from ...`) after each signed commit's header, matching git; unsigned commits are unchanged. `Version.Verify` gained an output-capturing verify path (`Verify_Object_Reporting`), and `Version.Log` threads a `Show_Signature` flag. The gpg block is byte-identical to git's (same gpg/key/commit); verified against real git + gpg. (`merge --verify-signatures` was already enforced.)
- Git parity: a relative `includeIf.gitdir:./` condition supplied via `GIT_CONFIG` env vars is now applied (matching git 2.54, which evaluates it against the repository and honours the named include). Previously version skipped it; the config-include base for env-provided conditions is anchored at the repository's git dir.
- Git parity: reftable ref storage is now read **and written** (`extensions.refStorage = reftable`, `repositoryformatversion = 1`). A new `Version.Reftable` package parses the binary table stack (`.git/reftable/tables.list`) — 24-byte header, prefix-compressed varint ref records with restart points, value types (deletion/oid/oid+peeled/symref), stack merged newest-wins — and `Version.Reftable.Writer` serializes a git-readable table (ref block + restart points + CRC32 footer). All ref reads (`Version.Refs`, `Version.Ref_Cache`, `Version.Tags`, `Version.Ref_Format`) and writes (`Version.Ref_Transaction`, HEAD updates, branch switch) route through the backend when the repo is reftable, so `log`/`status`/`branch`/`tag`/`commit`/`merge`/`checkout`/`for-each-ref`/`show-ref` work on git-created reftable repos. `init --ref-format=reftable` creates a git-readable reftable repository (config `refstorage=reftable` + `repositoryformatversion=1`, `.git/HEAD` `.invalid` stub, initial table with the HEAD symref). The **reflog** is stored in reftable log blocks too: `Version.Reftable` reads and `Version.Reftable.Writer` writes the zlib-compressed log block (records keyed by refname + reversed update index; committer/time/message value), and `Version.Reflog` routes reads and appends through it, preserving log history across ref rewrites. Writes are **incremental**: each transaction appends a small table (`Version.Reftable.Writer.Append_Table`) at the next update index, and **geometric auto-compaction** merges the two newest tables while the older is under twice the newer's size — keeping the stack to O(log n) tables and per-update cost proportional to the change, not the whole stack. Tombstones are preserved through merges so deletions stay masked; a reflog-only transaction produces a log-block-first table (no empty ref block). Verified against git 2.54 both directions: version reads git's tables and reflog (HEAD symref, branches, lightweight/annotated tags, `git reflog`) matching `show-ref`/`rev-parse`/`reflog`; git reads version-written and version-initialized tables and reflog `fsck`-clean and commits into them; ~75 mixed operations compact to a 3-table `fsck`-clean stack.
- Git parity: revision syntax `<rev>:<path>` — resolves `<rev>` to a tree and looks up `<path>` (root or nested blob, a subtree, or the empty-path tree), so `cat-file`/`rev-parse`/`show <rev>:<path>` work. The rev part accepts `^`/`~` (e.g. `HEAD~1:file`); a missing path errors. Verified against git for SHA-1 and SHA-256 repos.
- Docs: recorded that the SHA-256 object format is implemented (the header of `SHA256_SCOPE.md` and the ROADMAP were stale — they still said "rejected"). `init --object-format=sha256` creates git-compatible SHA-256 repositories (64-hex/32-byte ids, wider pack `.idx`, SHA-256 pack/index/commit trailers); read+write over local and smart HTTP/SSH transport (format negotiated via the `object-format=sha256` capability). Re-verified end-to-end against system git: version-created sha256 repos are `fsck`/`verify-pack`/`bundle verify` clean and readable by git, and version reads git-created sha256 repos (log/status/ls-tree/cat-file/branch/tag/clone). One format per repo, never mixed.
- Git parity: `rebase --rebase-merges` now pauses on a conflict and is resumable with `--continue` — a conflicting linear commit or two-parent-merge recreation records a merge state and persists the topological-replay position + original→rebased map (a `merges` mode in the rebase state), and `--continue` commits the resolution (recreating the merge with its rebased parents) and replays the rest; `--abort` restores the original tip (verified differentially against git: conflict → resolve → continue reproduces git's parent count, tree, subjects, and onto-upstream placement). Octopus (>= 3 parent) conflicts still abort, matching git's all-or-nothing octopus.
- Git parity: credential-helper protocol — `credential fill`/`approve`/`reject` drive the configured `credential.helper` program(s) (git's get/store/erase), with `fill` output byte-identical to `git credential fill` (verified differentially). Helper resolution follows git's `!shell` / path / `git-credential-<name>` rules. Transport auto-invocation on HTTP auth remains a follow-up.
- Git parity: annotated-tag GPG signing (`tag create -s` / `-u <key>`) appends the ASCII-armored PGP signature to the tag object, and `verify-commit`/`verify-tag` extract the signature and run `gpg --verify`. Verified bidirectionally against real git with a real key: version-signed commits/tags pass `git verify-*`, and git-signed commits/tags pass `version verify-*`. (Commit signing via `-S`/`commit.gpgsign` already existed.)
- Git parity: Git LFS objects are now uploaded on push (git-lfs pre-push behavior) — pushing a branch copies the media backing any reachable LFS-pointer blob into the configured LFS store (`lfs.url`, else the remote URL) when that store is a local directory, completing the local clean→push→clone→smudge round trip. HTTP/SSH LFS upload remains a follow-up; download (smudge from a local dir, HTTP batch, or SSH) was already supported.
- Git parity: `clone --filter=tree:<depth>` is now evaluated locally (selective copy) in addition to `blob:none`/`blob:limit` — commits and every tree/blob within `<depth>` of a commit's root tree are copied and deeper objects are omitted and lazily fetched from the promisor, matching git's `tree:<depth>` keep-set (verified against `git rev-list --filter=tree:N` and a `file://` clone with `uploadpack.allowFilter=true`). `sparse:oid` remains negotiated over HTTP/SSH but not yet evaluated locally.
- Git parity: line-ending normalization via `core.autocrlf` (true/input/false), `core.eol`, and `.gitattributes` (`text`/`-text`/`text=auto`/`eol=lf`/`eol=crlf`, plus the old `crlf` synonyms and the `binary` macro). Check-in collapses CRLF→LF and checkout expands LF→CRLF per the effective policy, with git's NUL-byte binary autodetection; `status` normalizes the same way so a converted working-tree file is not reported modified (verified differentially against git across check-in, checkout, and status; default `core.autocrlf=false` with no attributes stays byte-for-byte identical, and the scan skips the filter when nothing is configured). `.gitattributes` `export-subst` in `archive` remains pending.
- Git parity: `archive --format=tar.gz` (and `tgz`, plus `-o NAME.tar.gz`/`.tgz` suffix inference) produces a gzip-compressed tar; the gzip member is standard (any gunzip/git decompresses it back to the exact tar). `.tar.gz`/`.tgz` output paths are now accepted instead of rejected (freeze-noted: these previously raised "unsupported output"). `export-subst` keyword expansion is deferred to the `.gitattributes` work.
- Git parity: `push REMOTE <refspec>...` accepts multiple refspecs in one invocation and expands wildcard refspecs (`refs/heads/*:refs/heads/*`) to one push per matching local ref; `push --delete REMOTE REF...` deletes several refs at once. Updates are sent as separate ref requests (matching git's default non-atomic end state; a single batched receive-pack request and the bare `:`/`push.default=matching` refspec remain follow-ups). Lifts the previous "too many push arguments" restriction (freeze-noted: multi-operand push was rejected before).
- Git parity: `rebase --rebase-merges` now recreates octopus (>= 3 parent) merge commits via git's iterated merge-octopus strategy (verified differentially against git: the recreated merge yields a byte-identical tree, the correct parent count, and the rebased parent tips). Conflicts during `--rebase-merges` still abort cleanly (resumable pause for this path remains pending).
- Git parity: bare `rebase --root` (no `--onto`) recreates the whole current branch from a parentless root onto an empty base, preserving trees, messages, and authors (verified differentially against git; commit ids differ only by the replay committer timestamp, as with every version replay). Reuses the rebase state machine so `--continue`/`--abort` work.
- Git parity: `bundle unbundle FILE` unpacks a bundle's packfile into the object store (building a pack index) and prints its ref lines, matching git (objects become readable; refs are not created; recorded prerequisite objects must already be present). Clone-from-bundle remains a follow-up.
- Git parity: `config set --worktree` / `config unset --worktree` write to `$GIT_DIR/config.worktree` when `extensions.worktreeConfig` is enabled (byte-identical to git's `config --worktree`), falling back to the common config otherwise; per-scope reads/writes no longer merge worktree entries into the common config. Completes the `worktreeConfig` extension (read + write).
- Git parity: `update-index` plumbing — `--add`/`--remove`/`--force-remove` of working-tree paths, `--cacheinfo <mode>,<sha>,<path>` (and the three-argument form) to insert an entry for an existing blob, `--chmod=(+|-)x` to set the index exec bit, plain path update of an already-tracked file, and `--`/`--refresh` handling; new paths require `--add` (git's "missing --add option?" gate). Verified differentially against git by comparing resulting index state.
- Git parity: `cat-file --batch` and `--batch-check` read object names from stdin and emit git's batch format (`<oid> <type> <size>` header, plus raw contents for `--batch`), with `<token> missing` for unresolvable names and custom `--batch[=<fmt>]`/`--batch-check[=<fmt>]` templates over `%(objectname)`/`%(objecttype)`/`%(objectsize)`/`%(rest)` (verified differentially against git).
- Git parity: `for-each-ref` now supports `--format=<fmt>` (%(refname[:short]), %(objectname[:short[=N]]), %(objecttype), %(objectsize), %(HEAD), %(subject), %(author*)/%(committer*)/%(tagger*) name/email/date with `:iso`/`:iso-strict`/`:short`/`:unix`/`:raw` date modifiers, `%%` and `%xx` escapes), `--sort=<key>` (with leading `-` for descending; dates sort chronologically), `--count=<n>`, and shell-glob patterns (WM_PATHNAME) in addition to the literal prefix rule; the default output is unchanged and all refs under `refs/` (loose + packed) are enumerated (verified differentially against git).
- Added interactive-rebase `exec` (`git rebase -i`): an `exec`/`x <command>` todo line runs the command via the shell at its todo position (interleaved before/between/after picks); a non-zero exit stops the rebase with a non-zero status, and `rebase --continue` advances past the failed exec without re-running it, matching git (verified differentially; exec combined with squash/fixup is rejected). Completes the interactive action set.
- Added interactive-rebase `edit` (`git rebase -i`): an `edit`/`e` todo line replays the commit then stops with a clean tree at it (branch moved onto it so amends/new commits land there), and `rebase --continue` replays the rest on top of the possibly-amended tip; a conflicting edit stops once for the conflict and does not re-stop, matching git (verified differentially; edit combined with squash/fixup is rejected).
- Added interactive-rebase `reword` (`git rebase -i`): a `reword`/`r` todo line replays the commit and opens the message editor, with git `cleanup=strip` message handling, empty-message abort, and reword-after-conflict on `--continue` (reword combined with squash/fixup is rejected).
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
- Added direct stash test-support coverage for ref/log path helpers, strict reflog line formatting, broken-chain fixture generation, and synthetic stash storage writes.
- Reused Version.Stash_Test_Support in ordinary stash tests for stash ref/log path assertions, removing remaining hard-coded removal checks.
- Extracted shared stash storage corruption fixture helpers into Version.Stash_Test_Support for ref/log paths, reflog line construction, synthetic stash storage, and broken-chain fixtures.
- Froze CLI diagnostics for broken stash reflog old-id chains, covering command-failure status, redaction, and no-mutation behavior for list/show paths.
- Added stash reflog old-id chain validation so multi-entry stash stacks reject internally inconsistent reflogs before list/resolve operations, with no-mutation coverage.
- Tightened stash reflog parsing to validate old/new object ids, separators, and tab-delimited messages, with malformed-shape coverage preserving the named malformed-reflog diagnostic.
- Promoted malformed stash reflog and inconsistent stash storage messages to public stash diagnostic functions and routed implementation/CLI tests through that shared contract.
- Froze CLI diagnostics for malformed stash reflogs and refs/stash-versus-reflog mismatches, including nonzero exit status, redaction, and no-mutation checks for list/show/apply/drop paths.
- Added stash refs/stash versus newest reflog consistency validation so list, resolve, show, and apply reject split-brain stash storage without mutation.
- Hardened stash stack storage handling so drop validates the selected stash object before rewriting the stack, with corruption coverage for malformed stash reflogs, missing reflog targets, pop/branch no-mutation, and clear of inconsistent storage.
- Added command-boundary stash corruption coverage for create/store/show/apply paths, asserting corrupt indexes or stash objects fail without stack mutation or partial working-tree writes.
- Normalized default `stash store COMMIT` list messages to use the stored stash commit subject, while preserving `stash store -m MESSAGE COMMIT` overrides.
- Added accurate CLI feedback for pathspec-limited stash apply/pop no-match cases, preserving the stash while reporting `no matching paths in stash`.
- Consolidated stash untracked-parent apply handling so full and pathspec-limited apply share the same safety/write path.
- Added CLI subprocess coverage for expanded stash forms, including pathspec show/apply/pop routing and `stash store -m` list-message behavior.
- Hardened pathspec-limited stash apply with selected-path preflight so tracked restores and untracked collision checks happen before any selected writes.
- Added pathspec-limited `version stash apply [stash@{N}] [PATH...]` and `version stash pop [stash@{N}] [PATH...]`, including selected tracked/untracked restore and no-match pop preservation.
- Added pathspec filtering to `version stash show [--patch] [stash@{N}] [PATH...]`, covering tracked and untracked/ignored stash paths.
- Added `version stash store -m MESSAGE COMMIT` support so stored stash commits can carry explicit list/reflog messages while preserving stash-shape validation.
- Added `version stash create` and `version stash store COMMIT` plumbing for writing stash-shaped commits without worktree cleanup and later placing them on the stash stack.
- Added `version stash clear` to remove the full stash stack, including refs/stash and its reflog.
- Added `version stash show [--patch] [stash@{N}]` for read-only stash path summaries and patch inspection, including untracked/ignored stash parents.
- Added `version stash push --include-ignored [PATH...]`, including pathspec-filtered ignored-file stash, removal, and apply restore coverage.
- Added `version stash branch NAME [stash@{N}]`, creating a branch at the stash base, applying the selected stash, and dropping only after successful apply.
- Added pathspec-limited `version stash push [PATH...]` support, including selected tracked changes, no-match no-op behavior, and selected untracked handling with `--include-untracked`.
- Added POSIX symlink checkout/restore materialization for committed `120000` entries, with path restore, index restore, full checkout, and path checkout regression coverage.
- Added `tools/bin/check_ref_transaction_selftest` as a release-facing smoke test for expected-old ref transaction behavior.
- Updated platform CI evidence to require `ref_transaction=passed` alongside `ref_write_policy=passed`, with verifier, summarizer, selftest, and release consistency coverage.
- Documented the `Version.Files.Rollback` child package boundary for backup-rollback replacement, keeping `Version.Files.Atomic_Replace` as the normal file replacement API while exposing rollback backup path naming for focused tests and diagnostics.
- Added `version branch list --merged [BRANCH]` and `version branch list --no-merged [BRANCH]` as read-only aliases for `version branch merged [BRANCH]` and `version branch unmerged [BRANCH]`, with help/docs coverage.
- Added `version branch list --contains REV` as a read-only alias for `version branch contains REV`, with help/docs coverage.
- Added read-only `version branch list --verbose` support for compact branch inspection with current marker, short tip id, and commit subject, with help/docs and regression coverage.
- Added read-only `version tag list --points-at REV` support for exact lightweight tag/ref matching, with packed/loose tag, HEAD, unknown-revision, help, and no-mutation coverage.
- Added `version config set KEY VALUE` support for deterministic local config key creation/update while preserving unrelated entries, with stable help/docs/test coverage.
- Added `version config unset KEY` support for narrow local config key removal, with preservation of unrelated entries and stable help/docs/test coverage.
- Added `version remote prune NAME` as a mutating stale remote-tracking ref cleanup, with live-ref preservation, missing-remote rejection, SSH upload-pack discovery routing, and help/docs coverage.
- Added direct system-SSH subprocess pipe streaming at the transport boundary, with fake-SSH tests for argv, stdin/stdout, and nonzero-exit handling.
- Added SSH fetch over upload-pack streams, including depth-limited shallow negotiation and advertised tag following, with fake-SSH integration coverage that delegates to local `git-upload-pack` without network access.
- Added SSH clone default-branch discovery and checkout over upload-pack streams, including depth-limited shallow clone and remote tag coverage.
- Added non-shallow SSH push over receive-pack streams, with raw advertisement parsing and fake-SSH integration coverage.
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
- Added read-only `version tag show NAME` support for stable lightweight and annotated tag inspection, with packed and missing-tag coverage plus help/docs updates.
- Added read-only `version tag peel NAME` support for printing peeled lightweight or annotated tag target ids, sharing the same peeling behavior used by `tag list --points-at`.
- Added read-only `version tag list --contains REV` support for listing tags whose peeled commit contains a resolved commit revision.
- Tag deletion now reports the deleted tag ref object id in its success text, with loose and packed coverage.
- Added `version tag rename OLD NEW` for ref-level tag renames without rewriting tag objects, with loose, packed, and failure-path coverage.
- Added explicit tag target creation with `version tag create NAME REV` and `version tag create -a NAME REV -m MESSAGE`, preserving HEAD defaults and covering missing/duplicate failure paths.
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

## Phase 43 - General completeness pass
- Added centralized command-unavailable diagnostics and CLI freeze tests for missing repository, remote/upstream, sparse, linked-worktree, and unsupported-format preconditions.
## Phase 43 - Submodule status display polish

- Added stable labelled `version submodule status` output for clean, missing, advanced, and dirty submodule states.
- Added testable submodule status formatting helpers and CLI-facing regression coverage for the display contract.
- Updated command, usage, testing, and release documentation for the submodule status markers and labels.


- Added consistent CLI help/version affordance coverage for `version -h`, `version COMMAND --help`, `version COMMAND -h`, and centralized `version --version` output.
- Added `tools/bin/check_documentation_coherence` and wired it into release consistency/package gates so stale diagnostics, malformed release notes, and missing release-gate documentation are caught.
- Cleaned README release-gate examples into copy-pasteable shell blocks.
- Rewrote release notes into a coherent release-facing baseline plus Phase 43 stabilization summary.
- Replaced stale internal HTTP helper diagnostics that still said `the old HTTP not-implemented wording` with precise smart-transport/local-git-dir wording.


- Added `tools/bin/check_test_scope_completeness`, a release gate that verifies Phase 43 release-critical test suites remain present, registered, documented, and above the closure routine-count floor.
## Phase 43 - Hook late-failure edge coverage

- Expanded hook semantics coverage for no-op saves, object-storage failures before commit completion, frozen hook failure diagnostics, and rebase-continuation post-commit failures.
- Hardened `version save` so an unchanged index tree is a true no-op: it does not create a replacement commit and does not run commit hooks.
- Added rebase continuation coverage proving a failing `post-commit` is reported after the continuation commit remains Git-readable and the completed rebase state is not rolled back.


## Phase 43 - Cross-feature interaction matrix coverage

- Added a dedicated cross-feature regression suite covering sparse restore with submodule gitlink boundaries, sparse-excluded submodule restore no-mutation behavior, linked-worktree submodule restore isolation from the primary worktree, linked-worktree `post-commit` root/environment semantics, archive sparse-checkout independence with gitlink placeholders, and corrupt shallow fetch preservation of both existing refs and `.git/shallow`.

## Phase 43 - Restore/submodule gitlink interaction coverage

### Phase 43 platform CI evidence pass

- Added `tools/bin/check_platform_ci_evidence` so POSIX and Windows platform gate results can be verified as release evidence for the same source tree.
- Updated POSIX/Windows platform gates to emit evidence files when `VERSION_PLATFORM_CI_EVIDENCE_DIR` is set.
- Updated the copy-ready CI matrix to upload POSIX/Windows evidence and verify it in a dependent job.

### Phase 43 platform CI confirmation pass

- Added POSIX and Windows platform CI gate scripts so platform-sensitive tests are confirmed on real hosts rather than only by simulated path-policy fixtures.
- Added a copy-ready GitHub Actions platform matrix template under `ci/`.
- Added CI documentation and documentation tests requiring the platform gates to remain present.


- Expanded fetch-ingestion corruption coverage so bad pack checksums, missing delta bases, and advertised-object mismatches received from HTTP upload-pack fail without updating or creating remote-tracking refs and without leaving temporary pack/index artifacts.
- Added restore regression coverage proving directory restore preserves gitlink entries, restores ordinary parent files without recursing into submodule worktrees, staged directory restore preserves gitlink mode/object ids, and dirty submodule worktree files are not overwritten by parent restores.

## Phase 43 - Hook execution semantics expansion

- Expanded object and pack corruption coverage: corrupt loose zlib streams, missing loose-object headers, declared-size mismatches, loose-object hash mismatches, malformed tree entries, missing/invalid commit tree headers, truncated packs, bad pack checksums, missing ref-delta bases, and truncated pack indexes are now tested for deterministic rejection without leaving generated indexes.
- Hardened object/pack readers so loose objects verify declared size and object id hash, and pack indexing verifies the pack trailer checksum before writing an index.

- Added post-commit timing and environment coverage proving the hook observes the updated HEAD, runs from the repository root, receives `GIT_WORK_TREE`/`GIT_INDEX_FILE`, restores caller hook environment, and is skipped when commit creation is blocked before mutation.
- Added hook execution contract tests for stable empty result-output capture and POSIX non-executable hook no-op behavior.
- Changed `Run_Post_Commit` to report non-zero post-commit exits to the caller after the commit/ref/reflog update has completed, preserving the documented no-rollback behavior while surfacing hook failure.

## Phase 43 - Transport failure mutation-safety tests

- Added HTTP fetch failure regression coverage for malformed upload-pack pkt-lines and truncated pack payloads.
- Hardened failed HTTP fetch cleanup so temporary fetched packs are removed when demuxing or pack indexing fails before refs are updated.


## Phase 43 - Small compatibility and freeze consistency

- Documented `post-commit` as part of the frozen supported hook allow-list and aligned hook/security/compatibility docs.
- Added `tools/bin/check_release_consistency` and wired it into release/package documentation to catch command, hook, archive, and unsupported-scope drift.
- Implemented tracked directory restore expansion for working-tree and staged restore paths while leaving unrelated untracked files untouched.
- Added relative submodule URL resolution for common `./` and `../` forms against the configured superproject remote URL.

## Phase 42 release stabilization completeness pass 2

- Expanded the release checklist so every Phase 42 required smoke workflow is explicitly frozen: init/stage/save/fsck, local clone branch switching, local fetch/push, TAR/ZIP archive export, restore/checkout paths, replay conflict workflows, worktree add/remove, and submodule update.
- Added documentation regression coverage that checks the release checklist names each required release smoke workflow and repeats the no-public-internet requirement.
- Added an explicit release error-reporting policy requiring expected user/repository/transport/hook failures to avoid raw Ada exception traces or implementation dumps.
- Tightened release-package artifact rejection for Alire local state and native binary/library outputs such as `.exe`, `.dll`, `.so`, `.a`, and `.dylib`.

## Phase 42 release stabilization pass 1

- Added `docs/RELEASE_FREEZE.md` to freeze the 1.0 command surface, exit-code policy, repository-format limits, transport limits, archive behavior, hook behavior, Windows limitations, and packaging policy.
- Hardened `tools/bin/check_release_package` so it accepts both flat and root-prefixed release archives while rejecting generated artifacts, local VCS/build directories, scratch outputs, temporary archives, and root `alire.toml` parent-directory pins.
- Added release-critical regression coverage for exact binary-file round-trip through Version-created commits and for required release-freeze documentation.

### Phase 41 scalability completeness pass 20

## Phase 41 scalability completeness pass 21

- Optimized shallow-boundary normalization and fetch shallow-update merging.
- `.git/shallow` read/write normalization now deduplicates through command-local ordered sets instead of repeated vector membership scans.
- Smart-HTTP shallow/unshallow response application now builds ordered sets for existing and unshallow ids, avoiding nested scans while preserving deterministic shallow-file output.


- Continued maintenance loose-object discovery scalability by adding command-local ordered-set membership while scanning `.git/objects`, so large loose-object directories no longer rely on repeated result-vector scans to preserve uniqueness.

- Continued Phase 41 branch/integration scalability by routing merge-tree setup and integration-abort cleanup through command-local object/tree caches, and by replacing target-only cleanup path membership scans with an ordered path set.
- Continued Phase 41 branch-tracking scalability by replacing ahead/behind reachable-commit vector membership with command-local ordered object-id sets, adding command-local object and shallow-boundary caches to tracking walks, and adding divergent ahead/behind regression coverage.
- Continued Phase 41 shallow-history scalability by adding `Version.Shallow_Cache`; log, history, maintenance verification, prune filtering, and reachability traversal now load `.git/shallow` once per command-local cache instead of rereading it during each commit/object boundary check.
- Continued Phase 41 history scalability by replacing ancestry, merge-base, and reachable-object traversal vector-membership scans with command-local ordered object-id sets and by routing commit/tree reads through a command-local object cache, with reachable-object regression coverage for commit traversal.
- Continued Phase 41 restore/checkout scalability by routing restore/index materialization commit/tree reads through command-local object/tree caches and replacing index-vs-tree deletion checks with an ordered tree path map, preserving safe preflight and sparse semantics.
- Continued Phase 41 ordering scalability by replacing quadratic bubble/selection sorts in status change lists, diff side vectors, staging index entries, and shallow object-id writes with Ada container generic sorting while preserving deterministic path/object ordering.
- Continued Phase 41 diff/pathspec scalability by routing working-tree diffs through the pathspec-aware working-tree scan, loading ignore/tracked-path context once, and replacing tracked-working matching with an ordered map instead of per-index-entry linear searches.
- Continued Phase 41 maintenance/reachability scalability by replacing traversal membership checks with command-local ordered object-id sets, using set membership for prune unreachable filtering, verifying repack output through a freshly loaded pack-index cache instead of repeated pack index scans, and adding a duplicate-root reachability regression.
- Continued Phase 41 archive scalability by caching selected archive entries once per export, de-duplicating explicit parent directories through an ordered set, and tracking ZIP entry names through an ordered set instead of repeatedly scanning central-directory metadata for duplicate checks.
- Continued Phase 41 pack scalability by making `Version.Pack_Write` stream PACK bytes directly to disk while maintaining an incremental SHA-1 trailer and using command-local object-cache reads during pack generation; this avoids retaining the complete pack body in memory before writing.
### Phase 41 scalability completeness pass 3

- Streamed smart-HTTP fetch upload-pack responses directly through incremental pkt-line and side-band demux into the temporary pack file, avoiding whole-response and whole-pack buffering before indexing.

### Phase 38 Windows portability completeness pass 6

- Strengthened archive completeness coverage for branch revisions, sparse-checkout independence, gitlink placeholders, symlink metadata preservation, control-character rejection for archive names and symlink targets, malformed output rejection, unsafe entry path rejection, deterministic repeated output, extracted binary/CRLF/compressed-looking byte checks, empty/no-match archives, exclusion pathspecs, long TAR paths, unsupported compressed output rejection, and stricter archive path/file-entry validation.
- Added Windows-aware `file:///C:/...` stripping so file remotes resolve to usable drive paths instead of synthetic `/C:/...` POSIX-style paths, while preserving ordinary POSIX `file:///tmp/...` behavior.
- Added a central `Version.Files.Rename_Directory` helper and routed submodule `.git` directory absorption through it so production directory renames are no longer performed ad hoc.
- Expanded Windows portability tests for file URL drive-path stripping.

### Phase 38 Windows portability completeness pass 5

- Removed production hook executability probing through POSIX helper programs, kept hook execution on the direct argv spawning path, added conditional Windows `.cmd` hook coverage, and replaced remaining portability-sensitive repository admin path joins with `Version.Files.Join`.

### Phase 38 Windows portability completeness pass 4

- Repaired repository `commondir` validation syntax, enforced Windows-safe filesystem component policy for branch, tag, remote, and remote-tracking ref names, and added security/windows portability regressions for reserved device names, trailing dots, and Windows-invalid ref filename characters.

### Phase 38 Windows portability completeness pass 3

- Hardened `Version.Files.Atomic_Replace` so directory or otherwise non-ordinary temporary sources fail deterministically before target mutation.
- Made filesystem-guard case-collision errors distinguish duplicate paths from ASCII case collisions with the Phase 38 user-facing wording.
- Reused shared drive-like Windows path classification in submodule URL ambiguity checks so `C:repo` is not treated as an scp-like remote.
- Expanded Windows portability regression coverage for leading backslash escapes, excessive path length failures, SSH/file/unknown scheme classification, and directory-source atomic replacement rejection.

### Phase 38 Windows portability completeness pass 2

- Added shared drive-like path classification for transport ambiguity so absolute and drive-relative Windows paths remain local while scp-like remotes remain SSH.
- Changed relative path normalization to reject duplicate separators as empty path components after backslash normalization while still rejecting traversal and trailing separators.
- Extended Windows portability regression coverage for duplicate-separator rejection, plain reserved device names, and drive-relative transport classification.
- Added a central path-length guard at filesystem boundaries and expanded atomic writes to additional repository state/admin files.

### Phase 38 Windows portability completeness pass

- Added shared Windows drive-path recognition in `Version.Platform` and reused it for transport and repository `.git` gitdir handling so `C:/...` and `C:\...` paths are not treated as SSH remotes.
- Changed repository initialization to derive `core.filemode` from platform executable-bit support, defaulting to false on Windows-like platforms.
- Tightened `Version.Files.Atomic_Replace` to follow the Windows-safe temp-write, close, delete-existing-target, rename-temp policy and clean up temporary files on failure.
- Added dedicated `Version.Windows_Portability.Tests` coverage for drive paths, backslash normalization, reserved names, invalid characters, trailing dot/space rejection, case collisions, gitdir path text, and filemode defaults.

- Consolidated optional `post-commit` handling into `Version.Hooks.Run_Post_Commit` so ordinary saves, amend saves, cherry-pick/revert replay commits, and completed rebase flows share the same non-rollback reporting behavior.
- Added regression coverage that cherry-pick-created replay commits use the shared `commit-msg` and `post-commit` hook path.
### Phase 35 completeness pass 3

- Moved `pre-commit` execution ahead of tree and commit object writes for ordinary saves and amend saves, reducing repository mutation when a blocking hook fails.
- Hardened hook-path resolution so unsupported hook names are rejected before path resolution and Windows can discover explicit `.cmd`, `.bat`, and `.exe` hook files without shell interpolation.
- Added regression coverage for post-commit non-rollback behavior, invalid hook-name rejection, and `pre-push` remote-name/remote-url arguments.
- Added `version push --no-verify --tags` as the no-remote shorthand matching `version push --tags`.


### Phase 35 completeness pass 2

- Moved commit hook message preparation into `Version.Hooks.Prepare_Commit_Message` so ordinary saves and replay-created commits share the same `pre-commit` / `commit-msg` behavior.
- Applied commit hooks to clean rebase, cherry-pick, and revert replay commits before commit object creation.
- Extended `pre-push` coverage to tag pushes and added API/CLI bypass support for `version push --no-verify --tags REMOTE` and `version push --no-verify REMOTE --tags`.
- Added regression coverage for `commit-msg` nonzero blocking behavior and current-directory restoration after hook failure.
- Fixed the pre-push remote-stability test command quoting.

- Phase 35 completeness pass 5: moved post-checkout dispatch into a shared hook helper and wired linked worktree add checkouts through it, with regression coverage that hooks from the common repository hooks directory run in the linked worktree root.


- Continued Phase 41 status/pathspec scalability by adding a pathspec-aware working-tree scan; path-filtered status still traverses conservatively for correctness, but non-matching ordinary files and gitlinks are no longer hashed or appended before final status filtering.
### Phase 41 scalability completeness pass 18

- Added cache-aware `Version.Restore` entry points for full commit restore, index materialization, working-path restore, and index-path restore.
- Routed `Version.Checkout` full commit checkout and single-path checkout through one command-local object/tree cache pair, avoiding duplicate target commit reads and duplicate target tree flattening across working-tree and index updates.
- Added restore regression coverage that asserts full commit restore plus index write reuse the same flattened tree cache while preserving restored file content.

## Phase 40 - Archive export

Added repository archive creation through `version archive`, with TAR and ZIP writers, revision/tree-based export, pathspec filtering, deterministic metadata, and safe submodule gitlink placeholders, Git symlink metadata preservation, control-character rejection for archive names and symlink targets, and unsafe symlink-target rejection. Archive output is generated from committed objects rather than the working tree or index. ZIP entries are emitted through the integrated Ada Zlib stored-deflate path. The archive command now rejects unknown long options before `--`, validates file-vs-directory output targets, and keeps partial writer failures from leaving open file handles.

- Phase 40 archive support now supports safe `--prefix DIR/` root rewriting for TAR and ZIP output and rejects unsafe archive prefixes.


## Phase 41 - Scalability completeness pass 4

- Replaced diff side/path union classification with ordered maps so old/new side lookups are deterministic without repeated linear scans.
- Indexed tracked working-tree paths, gitlinks, and tracked directory prefixes during scan setup so ignored-directory traversal can preserve tracked exceptions without repeatedly walking the full index.
- Added cache count accessors for command-local object/tree/pack-index caches and non-timing regression coverage that repeated object/tree reads remain bounded.

### Phase 41 completeness pass 19

- Routed cherry-pick, revert, rebase replay, and stash apply merge setup through command-local object/tree caches.
- Replay/apply flows now reuse cached commit reads and flattened base/current/target trees across merge preparation, working-tree restore, and index materialization.
- Public replay/stash command semantics remain unchanged; cache lifetime is still one command operation.

### Phase 41 completeness pass 15

- Added packed-ref storage to `Version.Ref_Cache` and routed revision ref probing through the command-local cache.
- Added non-timing regression coverage for packed-ref cache load/reload behavior.
- Added sparse-index `sdir` read expansion with desparsifying writes for mutating index commands; unsupported-feature diagnostics remain frozen for SHA-256 repositories, promisor sidecars without a configured partial-clone remote, HTTP/3/h2c/server-push capability gaps, and unsupported remote URLs.
- Added CLI tests that freeze the unsupported-feature diagnostic contract.
- Added `version doctor` and `version doctor --release` documentation and CLI test coverage.

- Phase 43 archive UX polish: added explicit unsupported-format suggestions and component-specific unsafe-prefix diagnostics.

- Added read-only `version config list` command with stable `section.key=value` output and tests.
