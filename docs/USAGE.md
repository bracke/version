# version CLI usage

`version` is a Git-compatible command-line tool with a stable, product-oriented command grammar.
It stores repository data in `.git` and is intended to remain interoperable with Git.

## General commands

```text
version
version help
version help COMMAND
version COMMAND --help
version COMMAND -h
version --quiet COMMAND [ARGUMENTS...]
version --help
version -h
version --version
version completion bash
version man
```

Running `version`, `version help`, `version --help`, or `version -h` prints grouped top-level help and exits successfully. `version completion bash` prints a bash completion script. `version man` prints generated `version(1)` roff text. `version help COMMAND`, `version COMMAND --help`, and `version COMMAND -h` print command-specific help and exit successfully.
`--quiet` is a global option before the command; it suppresses success messages but does not suppress errors or read-only command output such as `status`, `diff`, `log`, and `show`.
Unknown commands and invalid arguments print `error: ...` to stderr and return the usage-failure exit code.
Path-taking commands accept `--` as an option/path boundary and do not treat that boundary marker as a file path.

Exit code policy:

```text
0 = success
1 = repository operation failure, validation failure, or expected runtime failure
2 = command-line usage error
```

## Repository

```text
version init [PATH]
version init --bare [PATH]
version clone SOURCE TARGET
version clone --depth N SOURCE TARGET
version clone --filter SPEC SOURCE TARGET
version verify
version repack
version prune [--dry-run|--now]
version gc [--dry-run|--now]
```

## Changes

```text
version stage [-f|--force] [--] PATHSPEC...
version remove [--] PATHSPEC...
version restore [--] PATHSPEC...
version restore --staged [--] PATHSPEC...
version restore --source REV [--] PATHSPEC...
version restore --source REV --staged [--] PATHSPEC...
version restore --staged --source REV [--] PATHSPEC...
version save MESSAGE
version save -m MESSAGE
version save --no-verify MESSAGE
version save --no-verify -m MESSAGE
version save --amend MESSAGE
version save --amend -m MESSAGE
version save --amend --no-verify MESSAGE
version save --amend --no-verify -m MESSAGE
version status [--porcelain|--short|--branch] [--ignored[=MODE]] [--] [PATHSPEC...]
version check-ignore [-q|--quiet] [-v|--verbose] [--stdin] [-z] [-n|--non-matching] [--index|--no-index] [--] PATH...
version diff [--] [PATHSPEC...]
version diff --staged [--] [PATHSPEC...]
version diff --cached [--] [PATHSPEC...]
version diff REV1 REV2
```

## Branches

```text
version branch list
version branch list --verbose
version branch list --contains REV
version branch list --merged [BRANCH]
version branch list --no-merged [BRANCH]
version branch current
version branch exists NAME
version branch resolve NAME
version branch upstream [BRANCH]
version branch contains REV
version branch merged [BRANCH]
version branch unmerged [BRANCH]
version branch create NAME
version branch switch NAME
version branch rename OLD NEW
version branch rename NEW
version branch delete NAME
version branch delete --force NAME
version branch delete NAME --force
version branch integrate NAME
version branch integrate --finalize
version branch integrate --abort
version branch finalize
version merge [OPTIONS] [TARGET...]
version merge --continue [--verify|--no-verify]
version merge --abort
version merge --quit
version branch set-upstream BRANCH REMOTE REMOTE_BRANCH
version branch unset-upstream BRANCH
version branch ahead-behind BRANCH
version branch update NAME
```

## Remotes

```text
version remote add NAME URL
version remote delete NAME
version remote remove NAME
version remote list
# Output: origin<TAB>https://example.invalid/project.git
version remote get-url origin
version remote exists origin
version remote set-url origin https://example.invalid/project.git
version remote rename origin upstream
version remote prune origin --dry-run
version remote prune origin
# Output: https://example.invalid/project.git
version fetch REMOTE
version fetch --depth N REMOTE
version push REMOTE
version push REMOTE BRANCH
version push --no-verify REMOTE BRANCH
version push --force REMOTE BRANCH
version push --delete REMOTE REF
version push REMOTE SRC:DST
version push REMOTE :DST
version push --tags REMOTE
version push REMOTE --tags
version push --no-verify --tags [REMOTE]
version push --no-verify REMOTE --tags
```

Supported remote URL families are local paths, `file://` local paths, smart HTTP(S),
and SSH-style remotes. Branch push supports these remote URL families. `push --tags` currently supports only local-path and `file://` remotes; HTTP(S) and SSH tag push are rejected before upload with `push --tags supports only local remotes`. SSH remote parsing accepts `ssh://[user@]host/path.git`,
`ssh://[user@]host:port/path.git`, `[user@]host:path.git`, and `host:path.git`.
For `ssh://` URLs, the slash after the host is preserved as part of the remote
path; use `ssh://host//absolute/path.git` when the remote shell must receive a
double-slash absolute path form. Bare `ssh://host/` is rejected because it has no
repository path. Windows drive paths such as `C:\repo`, `D:/repo`, and `C:repo`
remain local paths and are not classified as SSH remotes.

The Phase 24 SSH adapter owns URL parsing and deterministic direct-spawn `ssh`
argument construction for `git-upload-pack` and `git-receive-pack`; it does not
run a local shell. Real SSH authentication, known-hosts policy, key handling, and
subprocess pipe behavior are delegated to the system SSH backend; no credentials
are stored by `version`.

## History

```text
version log [<REV>...] [--] [PATH...]
version log --oneline [<REV>...]
version log [--skip=<n>] [--reverse] [--merges|--no-merges] [--first-parent]
version show [REV]
version checkout REV
version checkout REV -- PATHSPEC...
version tag [-a|-s|-u KEY] [-f] [-m MSG] NAME [REV]
version tag -d NAME...
version tag -v NAME...
version tag [-n[NUM]] [-l] [PATTERN...]
version tag --contains REV
version tag --merged REV
version tag --points-at REV
version tag --sort=KEY
version tag create NAME
version tag create NAME REV
version tag create -a NAME -m MESSAGE
version tag create -a NAME REV -m MESSAGE
version tag delete NAME
version tag remove NAME
version tag rename OLD NEW
version tag list
version tag list --points-at REV
version tag list --contains REV
version tag exists NAME
version tag resolve NAME
version tag peel NAME
version tag show NAME
```

`version tag create NAME` creates a lightweight tag at `HEAD`; `version tag create NAME REV` creates a lightweight tag at a resolved revision. `version tag create -a NAME -m MESSAGE` creates an annotated tag object at `HEAD`; `version tag create -a NAME REV -m MESSAGE` creates an annotated tag object at a resolved revision. `version tag list --points-at REV` prints tags whose peeled target is the resolved revision. `version tag list --contains REV` prints tags whose peeled commit contains the resolved commit revision. `version tag exists NAME` prints nothing and reports tag existence by exit status. `version tag resolve NAME` prints the object id stored in a tag ref and does not mutate repository state. `version tag peel NAME` prints the peeled target id for lightweight or annotated tags. `version tag show NAME` prints stable tag details without mutation; annotated tags include target and message details. Tag rename moves a tag ref without rewriting the target object. Tag deletion reports the deleted tag and its abbreviated old target, as git does.
`version tag remove NAME` is retained as a compatibility alias for `version tag delete NAME`.

`version tag` also accepts git's own grammar: `version tag NAME [REV]` creates, `-a`/`-s`/`-u KEY` annotate or sign, `-m MSG` supplies the message and implies `-a`, `-f` moves an existing tag, `-d` deletes, and `-v` verifies. Listing takes shell-glob patterns and combines its filters, so `version tag -n --contains REV` and `version tag -l 'v1.*' --sort=-refname` behave as in git. `-n[NUM]` prints the tag name in a 15-column field followed by the first `NUM` lines of its message -- the annotation for an annotated tag, the commit message for a lightweight one. Creating is silent; `-f` reports `Updated tag` only when the ref actually moves.
`version remote remove NAME` is retained as a compatibility alias for `version remote delete NAME`. `version remote exists NAME` is quiet and reports existence by exit status for scripts.
`version branch upstream [BRANCH]` is read-only and prints the configured upstream as `remote/branch`, using the current branch when BRANCH is omitted.

`version branch finalize` is retained as a compatibility alias for `version branch integrate --finalize`. `version merge [OPTIONS] [TARGET...]` is the Git-facing merge command; without an explicit target it can merge the configured upstream unless `merge.defaultToUpstream` is false. It accepts branch/tag/remote/commit revisions, fast-forward controls (`--ff`, `--ff-only`, `--no-ff`, plus `merge.ff` defaults), `--no-commit`, `--squash`, `-m/--message`, `-F/--file`, `--edit`/`--no-edit`, `--log[=<n>]`, `--signoff`, `--cleanup=MODE`, stat/summary switches, `--quiet`, `--verbose`, `--progress`/`--no-progress`, `--autostash`/`merge.autostash`, `-s/--strategy` (`ours`, `ort`, `recursive`, `resolve`, `octopus`, `subtree`), `-X ours|theirs|ignore-space-change|ignore-all-space|ignore-space-at-eol|ignore-cr-at-eol|renormalize|no-renormalize|find-renames[=<n>]|renames=<n>|rename-limit=<n>|find-copies[=<n>]|find-copies-harder|copies=<n>|no-copies|no-renames|directory-renames[=true|false|conflict]|no-directory-renames|diff-algorithm=patience|histogram|minimal|myers|subtree[=<path>]|recurse-submodules|no-recurse-submodules`, `--conflict=merge|diff3|zdiff3`, `--marker-size N`, rename threshold and rename-limit controls, `merge.renames` and `merge.renameLimit` config defaults, renormalize controls, `merge.renormalize` config defaults, rerere enablement, signature verification/signing controls, external `merge.<name>.driver` blob-conflict drivers with Git-like driver environment and `!merge` attribute resets, label placeholders, and built-in or delegated `merge.<name>.recursive` handling for virtual-base merges, `-Xsubtree=<path>` target/base path rewriting with conservative bare-subtree inference, and `--allow-unrelated-histories`, with `--continue`, `--abort`, and `--quit` for conflict workflows. Clean multi-target merges create an octopus commit; clean multi-target `--squash` writes squash state without advancing `HEAD`, and clean multi-target `--no-commit` writes multi-head merge state for `merge --continue`. `--autostash` uses `MERGE_AUTOSTASH` for merge-state recovery. Conflicted merges write Git-style unmerged index stages and `AUTO_MERGE`; continue and abort also understand Git-created conflicted merge state. Criss-cross merges can synthesize clean recursive virtual bases for the default/recursive engine, while `-s resolve` rejects multiple merge bases, the default strategy and selected diff algorithms including explicit Myers can merge independent multi-hunk insertions, materialize clean symlink additions by attempting host symlink creation when enabled, use plain link-target files when `core.symlinks=false`, and preserve one-sided regular-file mode changes on clean auto-merges and identical-content/mode-only changes, simple directory renames can carry additions into the renamed directory and ambiguous split directory renames pause, rename/rename preserves same-destination regular-file mode-only changes, and rename/add collisions keep unmerged stages, gitlink fast-forwards update checked-out submodule worktrees when possible while refusing dirty tracked/index/untracked submodule state and attempting normal fetch/nested-submodule update for missing checked-out targets when submodule recursion is enabled, and rerere-enabled merge and replay conflicts, including `rerere.autoupdate`, record side-order-independent preimage/postimage metadata and can reuse recorded resolutions by exact preimage content.
`version history` is retained as a compatibility alias for older history output.



## Archive export

```text
version archive REV
version archive REV --output PATH
version archive REV --format tar|zip
version archive REV [--] PATHSPEC...
```

Archive export writes TAR or ZIP source snapshots directly from the selected
revision tree. `--format tar|zip` may be used to choose the writer explicitly; unsupported compressed/proprietary suffixes produce a diagnostic suggesting `.tar`, `.zip`, and `--format`. It does not read dirty working-tree files, staged changes, sparse
checkout materialization, or submodule working directories. `--output` controls
the destination; `.zip`/`.ZIP` output names select ZIP when `--format` is omitted.
Compressed/proprietary-looking output suffixes such as `.tar.gz`, `.tgz`,
`.gz`, `.tar.xz`, `.txz`, `.xz`, `.tar.bz2`, `.tbz`, `.tbz2`, `.bz2`,
`.zipx`, `.7z`, and `.rar` are rejected case-insensitively because Phase 40
only emits uncompressed TAR and ZIP archives. Git symlinks are preserved as archive link metadata. Pathspecs restrict emitted archive
entries after revision resolution.

## Progress output

Long-running operations can be wired to `Version.Progress.Sink`. The CLI provides
`Version.CLI.Progress.Stderr_Sink` so progress/status messages are emitted on
stderr and remain separate from scriptable stdout command output.


## Worktree inspection

`version worktree list` is intended for humans and scripts that need stable high-level labels. Each line prints the path, marker brackets, and the checked-out branch or detached object id. The marker set includes `current`, `primary`, `linked`, `missing`, `detached`, and `branch-in-use`. Missing linked worktree metadata remains visible so users can repair or remove stale entries instead of losing track of them.

`version worktree current` prints only the current worktree line. It is useful in scripts that need to distinguish primary and linked worktree context without parsing the full list.

## Client-side hooks

Version supports a practical subset of Git-compatible client-side hooks from `.git/hooks` or, for linked worktrees, the common repository hooks directory. Phase 35 supports `pre-commit`, `commit-msg`, `pre-merge-commit`, `post-commit`, `post-merge`, `post-checkout`, and `pre-push` as the primary lifecycle hooks. Missing hooks are successful no-ops. On POSIX, a hook must be an ordinary executable file. Windows hook execution is intentionally conservative and limited to explicit executable-style hook files.

Commit hooks run in this order: `pre-commit`, message preparation, `commit-msg`, tree/commit creation, ref/reflog update, and optional `post-commit` reporting. Clean automatic merge commits also run `pre-merge-commit` before message preparation and commit creation; `--no-verify` skips it. A failing `post-commit` does not roll back the completed commit. `commit-msg` receives a message-file path and may edit it; Version reads the message file after the hook succeeds. `pre-push` runs before local, HTTP, or SSH push mutation/upload. `post-checkout` runs after branch, detached, or path checkout updates and receives old id, new id, and checkout flag arguments. `post-merge` runs after completed merge and squash workflows with Git-compatible squash argument `0` or `1`.

Use `version save --no-verify MESSAGE`, `version push --no-verify REMOTE BRANCH`, or `version push --no-verify --tags [REMOTE]` to bypass blocking hooks for that invocation. Hook execution sets `GIT_DIR`, `GIT_COMMON_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE`, and `VERSION=1`, runs with the repository root as the current directory, and restores the caller current directory and hook environment afterward. Timeout and full Git environment parity beyond the documented variables remain deferred.

Phase 35 replay-created commits produced by rebase, cherry-pick, and revert use the shared hook helpers from `Version.Hooks`, including message preparation and optional post-commit reporting for user-facing commits. Checkout operations, including linked worktree add materialization, use the shared post-checkout helper; linked worktrees discover hooks from the common repository hooks directory and execute them with the linked worktree root as `GIT_WORK_TREE`.
## Repository health check

Use `version doctor` for a quick non-mutating repository health check:

```sh
version doctor
```

Use `version doctor --release` from a source checkout to run the local release gate scripts before packaging:

```sh
version doctor --release
```

## Inspect local config

Use `version config list`, `version config keys`, `version config get KEY`, and `version config has KEY` to inspect or test the local repository config entries that Version reads. Use `version config set KEY VALUE` to create or update one local config key, and `version config unset KEY` to remove one local config key while preserving unrelated entries:

```sh
version config list
version config keys
version config get KEY
version config has KEY
version config set KEY VALUE
version config unset KEY
```

`version config list` output is stable `section.key=value` text. `version config keys` prints the same flattened names without values. `version config get KEY` prints only the matching value. `version config has KEY` prints nothing and reports key existence by exit status. `version config set KEY VALUE` deterministically rewrites local `.git/config` with the selected value. `version config unset KEY` removes the selected local config key. Quoted subsections are rendered in dotted form, for example:

```text
remote.origin.url=https://example.invalid/project.git
branch.main.merge=refs/heads/main
```


### Sparse checkout status

Use `version sparse status` to print `enabled` or `disabled` for the current repository sparse-checkout state without changing sparse patterns, config, index, or the working tree.
