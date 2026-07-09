# version

`version` is an Ada command-line version-control tool that stores data in an ordinary Git-compatible `.git` directory. The command interface is deliberately simpler and more explicit than Git, while the on-disk objects, refs, packs, index, reflogs, worktrees, submodules, and common repository layouts remain compatible within the documented scope.

Status: `0.1.0-dev`, pre-1.0. The documented workflows are intended to work; unsupported Git features are not implied.

Phase 42 development freezes the pre-1.0 behavior for release stabilization: documented commands, exit codes, repository-format limits, transport scope, archive behavior, hooks, Windows caveats, package cleanliness, and Git compatibility checks are now treated as release-critical.

## Build

This crate enforces GNAT 15 through Alire. The active manifests pin:

```toml
[[depends-on]]
gnat_native = "=15.2.1"
```

Do not run plain system GNAT, GPRBuild, GNATprove, GNATdoc, or related `gnat*`
tools from `PATH`. Build, test, and inspect the compiler through Alire so the
pinned toolchain is selected:

```sh
alr exec -- gnatls --version
alr build
alr exec -- gprbuild -P tests/tests.gpr
./tests/bin/tests
alr exec -- gprbuild -P tools/tools.gpr
tools/bin/check_examples
```

The version command must report `GNATLS 15.x`. Release manifest checks verify
the exact `gnat_native = "=15.2.1"` dependency in the root and tests manifests
before the release preflight builds through Alire.

Normal verification does not require public internet access. HTTP, SSH, submodule, rebase, archive, hook late-failure/no-op behavior, and Git compatibility behavior is covered by local fixtures, deterministic command/protocol boundaries, system Git acceptance checks, and explicit unsupported-scope checks.

## Quick start

```sh
version init demo
cd demo
printf 'hello\n' > hello.txt
version stage hello.txt
version save "initial"
version status
version status --porcelain
version status --short
version status --branch
version status --ignored
version check-ignore ignored.log
version diff --cached
version log
version log --oneline
version verify
git fsck --strict
```

## Supported command summary

Repository and maintenance: `init`, `clone`, `verify`, `repack`, `prune`, `gc`, `pack-refs`, `config list`, `config keys`, `config get`, `config has`, `config unset`.

Working tree and history: `stage`, `remove`, `save`, `status` including the stable `status --porcelain` subset, `status --branch` branch-header view, and `status --ignored`, `check-ignore`, `diff` including the `diff --cached` alias for staged output, `log` including `log --oneline`, `show`, `restore`, `checkout`.

Branches, replay, and temporary work: `branch`, `rebase`, `cherry-pick`, `revert` with `-m`/`--mainline` merge replay, `stash`, `tag` including `tag exists` for quiet existence checks, `tag resolve` for object-id lookup, and `tag show` for stable tag inspection.

Remotes and repository-layout workflows: `remote`, `fetch`, `push`, `sparse`, `worktree`, `submodule`. Sparse checkout includes a read-only `version sparse status` summary.

`version config list`, `version config keys`, `version config get KEY`, and `version config has KEY` inspect or test local repository config values that Version cares about; `version config set KEY VALUE` creates or updates one local config key, and `version config unset KEY` removes one local config key while preserving unrelated keys. `version config keys` prints only flattened dotted key names. `version config has KEY` is quiet and reports existence by exit status. `version tag create NAME` creates lightweight tags at `HEAD`; `version tag create NAME REV` creates lightweight tags at a resolved revision. `version tag create -a NAME -m MESSAGE` creates annotated tags at `HEAD`, while `version tag create -a NAME REV -m MESSAGE` creates annotated tags at a resolved revision. `version tag list --points-at REV` is a read-only tag query that prints tags whose peeled target is a resolved revision. `version tag list --contains REV` is a read-only reachability query for tags whose peeled commit contains a resolved commit revision. `version tag exists NAME` is a quiet read-only predicate that reports tag existence by exit status. `version tag resolve NAME` is a read-only diagnostic for printing the object id stored in a tag ref. `version tag peel NAME` prints the peeled target id for lightweight or annotated tags. `version tag show NAME` prints stable tag details, including annotated tag target and message. Tag rename moves a tag ref without rewriting the target object. Tag deletion reports the deleted tag ref object id.

Use `version help`, `version --help`, or `version -h` for top-level help. Use `version help COMMAND`, `version COMMAND --help`, or `version COMMAND -h` for command-specific grammar. Use `version --version` for the stable version string. Use `version completion bash` to print a bash completion script. Use `version man` to print generated `version(1)` roff text.

## Compatibility promise

Within the documented scope, repositories created or updated by `version` use standard Git-compatible storage so Git can inspect and continue using them. Compatibility means practical repository interoperability, not identical command names, exact output formatting, every Git configuration variable, or every edge behavior of Git.

## Limitations

Unsupported or intentionally narrow areas include SHA-256 object-format repositories, full Git protocol negotiation parity, advanced pathspec magic beyond basic attributes and unsupported case-insensitive matching, interactive/merge-preserving rebase, recursive merge strategy parity, credential-helper UX, server-side hooks, and complete Git submodule/worktree administrative parity. Unsupported-feature diagnostics are intentionally precise and stable for the release surface: SHA-256 object-format repositories, promisor sidecars without a configured partial-clone remote, unavailable HTTP/3/h2c/server-push transport features, and SSH streaming limitations must report the unsupported capability instead of a generic failure.

## Documentation

* `docs/COMMANDS.md` — command syntax, examples, and failure cases.
* `docs/ARCHITECTURE.md` — package ownership boundaries.
* `docs/COMPATIBILITY.md` — supported, partial, and unsupported Git-compatible workflows.
* `docs/REPOSITORY_FORMAT.md` — repository layout and on-disk compatibility.
* `docs/TRANSPORTS.md` — local, `file://`, HTTP(S), and SSH behavior.
* `docs/SECURITY.md` — safety boundaries and known limits.
* `docs/PORTABILITY.md` — POSIX/Windows filesystem policy.
* `docs/CI.md` — required POSIX/Windows release CI confirmation gates.
* `docs/MAINTENANCE.md` — verify, repack, prune, gc, and reachability.
* `docs/WORKTREES.md`, `docs/SUBMODULES.md`, `docs/HOOKS.md` — feature-specific scope.
* `docs/RELEASE_CHECKLIST.md` — release verification.
* `examples/` — copy-pasteable workflows, including archive export in `examples/archive_workflow.md`.


### Archive export

Create deterministic source snapshots directly from committed repository objects:

```sh
version archive HEAD --output source.tar
version archive HEAD --format tar --output source.tar
version archive HEAD --format zip
version archive v1.0 --output release.zip
```

Archives are generated from the selected revision tree, not from the working tree or index. TAR and ZIP preserve committed bytes, CRLF text, binary payloads, and symlink metadata; ZIP uses the project's Ada Zlib stored-deflate path. Output is deterministic for the same tree, `.ZIP` output names infer ZIP the same way as `.zip`, compressed/proprietary-looking suffix rejection is case-insensitive, and unsafe archive entry names plus unsafe symlink targets, including control-character names/targets, are rejected. Duplicate archive entry names and directory/file name collisions are rejected rather than producing extractor-dependent overwrites. Archive output is written through a same-directory temporary file and replaces the requested output only after successful completion, so failed exports do not leave partial archives or clobber an existing output file.

### Phase 43 CLI golden-output freeze

The release-stabilization test suite freezes CLI help, usage, status, submodule status labels, worktree list/current markers, unsupported-format, corruption, transport, hook, remote, archive, submodule, worktree, sparse, and command-boundary corruption output fragments so command-line behavior can be treated as a release contract. Command-boundary corruption fixtures also verify that status, stage, save, log, restore, branch switch, archive, submodule, and fetch fail safely without committing partial repository or output mutations.

Release packaging also includes the negative package-shape and platform-evidence gates:

```sh
tools/bin/check_release_package_selftest
tools/bin/check_platform_ci_evidence .release/platform-ci-evidence
tools/bin/summarize_release_evidence .release/platform-ci-evidence
tools/bin/check_documentation_coherence
```
### Doctor and release checks

`version doctor` performs a shallow local repository health check for repository discovery, supported repository format, readable `HEAD`, and readable index.

`version doctor --release` is a convenience wrapper for the release gate scripts in a source checkout. It does not replace CI; it runs the local metadata, documentation-coherence, test-scope, release-consistency, release-consistency self-test, and package self-test gates.


Command unavailable diagnostics are centralized and stable. Common preconditions such as missing repositories, missing remotes/upstreams, sparse-excluded paths, linked-worktree safety, and unsupported repository formats report precise `error: ...` messages before mutation.


See `docs/EDGE_CASE_EXAMPLES.md` for copyable examples of restore/submodule boundaries, archive safety, SHA-256 rejection, hook no-rollback behavior, transport no-mutation guarantees, and platform CI evidence validation.



Read-only inspection:

```sh
version branch current
version branch list --verbose
version branch list --merged main
version branch list --no-merged main
version branch exists main
version branch resolve main
version branch upstream main
version branch contains HEAD
version branch merged [BRANCH]
version branch unmerged [BRANCH]
version remote list
version remote get-url origin
version remote exists origin
version remote set-url origin https://example.invalid/project.git
version remote rename origin upstream
version remote prune origin --dry-run
version remote prune origin
```

`version branch list --verbose` is read-only and prints each branch with current marker, short tip id, and commit subject. `version branch list --contains REV` is a Git-compatible alias for `version branch contains REV`. `version branch list --merged [BRANCH]` and `version branch list --no-merged [BRANCH]` are Git-compatible aliases for `version branch merged [BRANCH]` and `version branch unmerged [BRANCH]`. `version branch current` is read-only and prints only the attached branch name plus a trailing newline. `version branch exists NAME` is quiet and reports branch existence by exit status. `version branch resolve NAME` prints the branch tip object id plus a trailing newline. `version branch upstream [BRANCH]` prints the configured upstream as `remote/branch` plus a trailing newline and defaults to the current branch. `version branch contains REV` is read-only and lists branch names whose tips contain the resolved commit. `version branch merged [BRANCH]` is read-only and lists branches already merged into the current or named branch. `version branch unmerged [BRANCH]` is read-only and lists branches not yet merged into the current or named branch. `version remote list` output is stable tab-separated `name<TAB>url` text. `version remote get-url NAME` is read-only and prints only the configured URL plus a trailing newline. `version remote exists NAME` is quiet and reports existence by exit status. `version remote set-url NAME URL` updates the URL of an existing remote without changing its fetch refspec. `version remote rename OLD NEW` renames an existing remote while preserving its URL and existing fetch refspec. `version remote prune NAME --dry-run` reports stale remote-tracking refs as `would prune NAME/BRANCH` lines without deleting them. `version remote prune NAME` deletes stale remote-tracking refs and reports `pruned NAME/BRANCH` lines.
