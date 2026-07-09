# version command reference

`version` uses a stable product-oriented command grammar. It does not try to clone every Git porcelain spelling.

## Global

```text
version
version --help
version -h
version --version
version --quiet COMMAND [ARGUMENTS...]
version help [COMMAND]
version COMMAND --help
version COMMAND -h
version completion bash
version man
```

`version completion bash` prints a static bash completion script for the current command surface. Source it directly or install it through your shell completion directory. `version man` prints generated `version(1)` roff text.

Exit codes: `0` success, `1` expected operation/validation failure, `2` usage error. User-facing errors use the `error:` prefix. `--quiet` suppresses success messages only.

## Pathspecs

Commands accepting `PATHSPEC...` support repository-relative literal paths, directory prefixes, `*`, `?`, recursive `**`, exclusions with `:!` or `:^`, top-anchored `:/path`, and long magic forms `:(literal)`, `:(glob)`, `:(top)`, and `:(exclude)`. Pathspecs filter command-owned candidates; they do not grant filesystem access outside the repository. Backslash separators are rejected with a stable diagnostic; use `/` in repository-relative pathspecs on every platform.

```sh
version stage src/**/*.adb :!generated/
version status -- '*.md'
version restore --source HEAD -- docs/**/*.md
```

## Ignore Files

Working-tree scans honor repository `.gitignore` files, local `.git/info/exclude`, `core.excludesFile` resolved through Git's system, global, and local config stack, and Git's default global ignore file when `core.excludesFile` is unset. Configured excludes are loaded first, then `info/exclude`, then worktree `.gitignore` files, so later sources can override earlier sources with normal negation syntax. `core.excludesFile` may be absolute, repository-relative, `~/`-relative when `HOME` is set, or `%(prefix)`-interpolated against the config path base; quoted config path values are accepted for paths containing spaces. The ignore engine also honors `GIT_CONFIG_SYSTEM`, `GIT_CONFIG_GLOBAL`, `GIT_CONFIG_NOSYSTEM`, `GIT_CONFIG_COUNT`, `GIT_CONFIG_KEY_<n>`, `GIT_CONFIG_VALUE_<n>`, `XDG_CONFIG_HOME`, and `HOME` for ignore config discovery, including `[include] path = ...`, matching `[includeIf "gitdir:..."] path = ...`, matching `[includeIf "onbranch:..."] path = ...`, and matching `[includeIf "hasconfig:remote.*.url:..."] path = ...` files that set `core.excludesFile`. Use `version check-ignore PATH...` to test path operands against the same ignore stack.

## Repository lifecycle and maintenance

### init

Syntax: `version init [PATH]`, `version init --bare [PATH]`.

Purpose: create a Git-compatible repository.

Example: `version init demo`.

Common failures: target cannot be created, unsafe path, invalid repository metadata.

### clone

Syntax: `version clone SOURCE TARGET`, `version clone --depth N SOURCE TARGET`, `version clone --recursive SOURCE TARGET`, `version clone --filter SPEC SOURCE TARGET`.

Purpose: clone a local path, `file://`, HTTP(S), or SSH repository. `--filter SPEC` (e.g. `blob:none`, `blob:limit=<n>`) makes a partial clone: over HTTP/SSH the filter is negotiated with the server, and over a local source `blob:none`/`blob:limit` are evaluated directly (richer specs are rejected for local sources). Omitted objects are fetched lazily from the promisor on first access. `--filter` cannot be combined with `--depth` or `--recursive`.

Example: `version clone ../remote.git clone`.

For `file://` clone sources, percent-escaped path bytes such as `%20` are decoded for filesystem access, `file://localhost/...` is accepted as a local path, non-local file URL authorities are rejected, malformed percent escapes are rejected, and the configured `origin.url` remains stored as provided. If clone creates the target directory and then fetch or checkout fails, the target directory is removed and the source repository is left untouched.

Common failures: target exists, unsupported scheme, malformed remote repository, malformed `file://` percent escape, missing objects, checkout preflight failure, unsupported depth on a transport.

### verify

Syntax: `version verify`.

Purpose: verify repository object consistency.

Common failures: missing object, corrupt object, corrupt pack, invalid HEAD.

### repack

Syntax: `version repack`.

Purpose: write reachable objects into Git-compatible pack/index files.

Common failures: missing reachable object, object read error, pack/index write error.

### prune

Syntax: `version prune [--dry-run|--now]`.

Purpose: report or remove unreachable loose objects subject to safety roots.

Common failures: invalid option, unsafe repository state, lock/write failure.

### gc

Syntax: `version gc [--dry-run|--now]`.

Purpose: run implemented repository maintenance.

Common failures: same reachability/object errors as repack and prune.

### config

Syntax:

```text
version config list
version config keys
version config get KEY
version config has KEY
version config set KEY VALUE
version config unset KEY
```

Purpose: print local repository config entries in stable `section.key=value` form, print only flattened config keys, print the value for one local config key, quietly test whether a key exists, set one local config key, or remove one local config key. Quoted subsections are rendered as dotted names, for example `remote.origin.url=...` and `branch.main.merge=refs/heads/main`. The inspection commands are read-only and do not inspect global user config. `version config has KEY` prints nothing, exits successfully when the key exists, and exits with command failure when the key is absent. `version config set KEY VALUE` creates or updates the selected key in local `.git/config` using deterministic rewrite semantics. `version config unset KEY` rewrites the local config without the selected key and preserves unrelated entries.

Examples:

```text
version config list
user.name=Ada User
user.email=ada@example.invalid
remote.origin.url=https://example.invalid/project.git
branch.main.remote=origin
branch.main.merge=refs/heads/main

version config keys
user.name
user.email
remote.origin.url
branch.main.remote
branch.main.merge

version config get remote.origin.url
https://example.invalid/project.git

version config has remote.origin.url
version config set remote.origin.tagOpt --no-tags
version config unset remote.origin.url
```

Common failures: repository discovery failure, malformed config file, missing config key for `get`/`unset`, absent key for `has`, unsupported repository format.

## Change creation and restoration

### stage

Syntax: `version stage [-f|--force] [--] PATHSPEC...`.

Purpose: add matching working-tree files or supported submodule gitlinks to the index. Use `-f` or `--force` to stage ignored matches.

Example: `version stage hello.txt src/`.

Common failures: no match, path outside repository, unsupported file type, sparse-excluded missing path.

### remove

Syntax: `version remove [--] PATHSPEC...`.

Purpose: remove matching tracked paths from the index and working tree.

Example: `version remove obsolete.txt`.

Common failures: no tracked match, unsafe deletion target, repository not open.

### save

Syntax: `version save MESSAGE`, `version save -m MESSAGE`, `version save --no-verify MESSAGE`, `version save --amend MESSAGE`, with `--amend --no-verify` and `-m` variants.

Purpose: create or amend a commit from the index.

Example: `version save "initial import"`.

Common failures: missing identity, empty/invalid state, hook failure, object/ref write failure.

### status

Syntax: `version status [--porcelain|--short|--branch] [--ignored[=traditional|matching|no]] [--] [PATHSPEC...]`.

Purpose: show deterministic working-tree, index, untracked, and optionally ignored status. `--porcelain` and its `--short` alias print the same stable project-specific machine-readable subset. `--branch` prepends a stable `## branch` header, including upstream/ahead/behind details when configured, before those same short entries: `S <A|M|D> path` for staged changes, `W <A|M|D> path` for working-tree changes, `? A path` for untracked files, and `! ! path` for ignored paths when requested. `--ignored` can combine with long, porcelain, short, or branch output; `--ignored=traditional` lists ignored files, `--ignored=matching` reports ignored directories that match a rule as directories, and `--ignored=no` disables ignored output. Clean porcelain status prints no output. The shorthand phrases `status --porcelain` and `status --short` refer to this stable subset.

Common failures: repository discovery failure, malformed index, unsafe repository path.

### check-ignore

Syntax: `version check-ignore [-q|--quiet] [-v|--verbose] [--stdin] [-z] [-n|--non-matching] [--index|--no-index] [--] PATH...`.

Purpose: test path operands against the repository ignore rules loaded from `core.excludesFile`, `.git/info/exclude`, and `.gitignore` files. By default the command honors the index, prints each ignored untracked operand in input order, omits non-matching operands, exits successfully when any operand is ignored, and exits with the command-failure status when none are ignored. `-q` and `--quiet` suppress output while preserving that predicate exit status. `-v`/`--verbose` prints `source:line:pattern<TAB>path` for paths matched by an ignore rule, including negations; with `-n`/`--non-matching`, unmatched operands are printed as empty source/line/pattern fields. `-z` switches output records to NUL delimiters; with `--stdin`, input is NUL-delimited too. `--no-index` checks tracked paths against ignore rules; `--index` restores the default index-honoring behavior when both are present.

Common failures: missing path operand, repository discovery failure, malformed ignore/config data.

### diff

Syntax: `version diff [--] [PATHSPEC...]`, `version diff --staged [--] [PATHSPEC...]`, `version diff --cached [--] [PATHSPEC...]`, `version diff REV1 REV2`.

Purpose: show working-tree, staged, or commit-to-commit differences. `--cached` is a byte-identical alias for `--staged`.

Common failures: unknown revision, malformed object, no eligible paths.

### restore

Syntax: `version restore`, `version restore [--] PATHSPEC...`, `version restore --staged [--] PATHSPEC...`, `version restore --source REV [--] PATHSPEC...`, and staged/source combinations.

Purpose: restore working-tree or staged paths from HEAD or another revision.

Common failures: unknown source revision, dirty target, no source match, filesystem-guard rejection.

### checkout

Syntax: `version checkout REV`, `version checkout REV -- PATHSPEC...`.

Purpose: detach at a revision or restore matching paths from a revision.

Common failures: unknown revision, dirty working tree, unsafe materialization target.

### reset

Syntax: `version reset [--soft|--mixed|--hard] [REV]`, `version reset [REV] -- PATHSPEC...`.

Purpose: move the current branch (or detached HEAD) to REV (default HEAD). `--soft` moves HEAD only; `--mixed` (default) also resets the index to REV; `--hard` also resets the working tree. The path form resets the index entries for PATHSPEC to their state in REV, leaving HEAD and the working tree untouched.

Common failures: unknown revision (fails before any mutation), unsafe working-tree materialization (`--hard`).

### reflog

Syntax: `version reflog [show] [REV]`.

Purpose: show the movement log for REV (default `HEAD`), newest first, formatted as `<short-id> <ref>@{N}: <message>` — matching `git reflog`.

Common failures: none for a missing reflog (prints nothing).

### pull

Syntax: `version pull [--rebase] [--ff-only] [REMOTE [BRANCH]]`.

Purpose: fetch from the remote and integrate it into the current branch. With no arguments it uses the branch's configured upstream; `REMOTE BRANCH` integrates `refs/remotes/REMOTE/BRANCH`. By default it merges (fast-forwarding when possible); `--rebase` rebases the current branch onto the fetched commit; `--ff-only` refuses a non-fast-forward.

Common failures: no upstream configured (and no REMOTE given), merge conflicts (left in the working tree, non-zero exit), non-fast-forward under `--ff-only`.

### mv

Syntax: `version mv [-f] SOURCE DEST`, `version mv [-f] SOURCE... DIR`.

Purpose: rename or move tracked file(s), updating both the index and the working tree. Moving multiple sources requires DEST to be an existing directory.

Common failures: source not under version control, destination already exists (use `-f`), missing source or destination.

### clean

Syntax: `version clean [-n] [-f] [-d] [-x]`.

Purpose: remove untracked files from the working tree. `-d` also removes untracked directories (reported collapsed, like git); `-x` also removes ignored files. `-n` previews (`Would remove ...`); one of `-n` or `-f` is required (clean refuses otherwise). Short flags may be combined (e.g. `-fd`).

Common failures: neither `-n` nor `-f` given (refuses to clean). Path arguments are not yet supported.

### bundle

Syntax: `version bundle create FILE REF...`, `version bundle verify FILE`, `version bundle list-heads FILE`.

Purpose: offline transport. `create` writes a v2 bundle (header plus a packfile of all objects reachable from the given refs; `REF` may be a branch name, `HEAD`, or `--all`). `verify` checks a bundle and lists its refs; `list-heads` prints its `<oid> <refname>` lines. Bundles produced here can be cloned/fetched by `git`, and git's bundles are read here.

Common failures: unrecognized ref, not a git bundle file.

### apply

Syntax: `version apply [--check] [PATCHFILE]`.

Purpose: apply a unified diff to the working tree (reading PATCHFILE, or standard input when omitted). Handles modify, create (`--- /dev/null`) and delete (`+++ /dev/null`) patches with `-p1` path stripping; the patch is validated in full before any file changes (`--check` stops after validation).

Common failures: malformed patch, context/deletion mismatch (patch does not apply). Not yet supported: `-R`, `-p` other than 1, `--index`/`--cached`, fuzz, binary patches, rename/mode-only patches.

### format-patch

Syntax: `version format-patch [--stdout] [-o DIR] REVISION`.

Purpose: write one mbox patch file per commit in REVISION's range, oldest first (`<since>` means `<since>..HEAD`; `<A>..<B>` is an explicit range). `--stdout` writes all patches to standard output; `-o DIR` selects the output directory (default: current). Output (RFC2822 author date, `[PATCH n/m]` subjects) is consumable by `git am`.

Common failures: unknown revision.

### am

Syntax: `version am [MBOX...]`.

Purpose: apply patches from one or more mbox files (as written by `format-patch`, or standard input when none are given), committing each on the current branch with its recorded author (name/email/date) and message. Consumes `git format-patch` output.

Common failures: a patch that does not apply (context mismatch). Conflict resolution (`--continue`/`--abort`/`--skip`) is not yet supported.

### cherry

Syntax: `version cherry [-v] [UPSTREAM [HEAD]]`.

Purpose: list commits reachable from HEAD (default) but not UPSTREAM (default: the branch's upstream), oldest first, marking each `+` (no equivalent upstream) or `-` (an equivalent change, by patch-id, already exists upstream). `-v` appends the subject.

Common failures: no upstream configured and none given.

### range-diff

Syntax: `version range-diff BASE..OLD BASE..NEW`.

Purpose: compare two revisions of a patch series, pairing their commits and marking each `=` (identical, by patch-id), `!` (matched by subject, content changed), `<` (only in OLD), or `>` (only in NEW). Matching uses patch-id then subject (not git's diff-similarity cost) and the inner diff-of-diffs is not shown, so output can differ from `git range-diff`.

Common failures: an argument that is not a `BASE..TIP` range.

### shortlog

Syntax: `version shortlog [-s] [-n] [REV]`.

Purpose: summarize history reachable from REV (default HEAD), grouped by author. By default lists each author's commit subjects; `-s` shows only counts; `-n` sorts authors by commit count.

### grep

Syntax: `version grep [-n] [-i] PATTERN`.

Purpose: search the working-tree content of tracked files for PATTERN — a fixed substring, not a regular expression — printing `path:text` (or `path:line:text` with `-n`); `-i` ignores case. Exits non-zero when nothing matches. Path arguments are not yet supported.

### describe

Syntax: `version describe [REV]`.

Purpose: name REV (default HEAD) relative to the nearest reachable tag — the tag itself when exactly tagged, otherwise `<tag>-<N>-g<short>`.

### notes

Syntax: `version notes add -m MSG [REV]`, `version notes show [REV]`.

Purpose: attach or show a text note on a commit (default HEAD), stored in refs/notes/commits. Notes are written flat (one entry per commit id), which git reads.

### blame

Syntax: `version blame [REV] FILE`.

Purpose: show, for each line of FILE at REV (default HEAD), the abbreviated commit that introduced it. Attribution is content-based (the most recent commit adding that exact line), not git's line-tracking algorithm, so results can differ for moved or duplicated lines.

## Plumbing

Low-level commands over the object/ref/index store, intended for scripts. Output matches `git`'s for the supported forms.

- `version cat-file (-t|-s|-e|-p) OBJECT` — object type, size, existence (exit status), or pretty content (`-p` of a tree lists entries recursively).
- `version rev-parse [--abbrev-ref] REV...` — resolve revisions to object ids (or the branch name for `--abbrev-ref HEAD`).
- `version ls-files` — list tracked (stage-0) index paths.
- `version ls-tree [-r] [--name-only] TREE-ISH` — list a tree's entries; one level by default (subtrees shown as `tree` entries), recursively with `-r`.
- `version hash-object [-w] [--stdin] [FILE]` — compute (and with `-w` write) a blob id.
- `version write-tree` — write the index as a tree and print its id.
- `version read-tree TREE-ISH` — replace the index with the contents of a tree.
- `version commit-tree TREE [-p PARENT]... -m MESSAGE` — create a commit object.
- `version update-ref REF NEWVALUE [OLDVALUE]` / `version update-ref -d REF [OLDVALUE]` — set or delete a ref (with optional compare-and-swap old value).
- `version symbolic-ref HEAD [REF]` — print the branch HEAD points at, or (with REF) point HEAD at REF without touching the working tree.
- `version show-ref` — list `<oid> <refname>` for branches and tags.
- `version for-each-ref [PATTERN]` — list `<oid> <objecttype>\t<refname>` for branches and tags, optionally filtered by a refname prefix.
- `version rev-list [--count] REV` — list (or count) commits reachable from REV.

## History

### log

Syntax: `version log [REV]`, `version log --oneline [REV]`.

Purpose: show commit history from HEAD or a revision.  `--oneline` prints one compact `<short-id> <subject>` line per commit using the same first-parent walk.

### show

Syntax: `version show [REV]`.

Purpose: show one commit and its changes.

Both fail on unknown revisions, missing commit objects, or malformed trees.

## Branches, tags, replay, and stash

### branch

Syntax: `version branch list`, `list --verbose`, `list --contains REV`, `list --merged [BRANCH]`, `list --no-merged [BRANCH]`, `current`, `exists NAME`, `resolve NAME`, `upstream [BRANCH]`, `contains REV`, `merged [BRANCH]`, `unmerged [BRANCH]`, `create NAME`, `switch NAME`, `rename OLD NEW`, `rename NEW`, `delete [--force] NAME`, `integrate NAME`, `integrate --finalize`, `integrate --abort`, `finalize`, `set-upstream BRANCH REMOTE REMOTE_BRANCH`, `unset-upstream BRANCH`, `ahead-behind BRANCH`, `update NAME`.

Purpose: inspect and manage branch lifecycle, tracking, and integration. `version branch list --verbose` prints sorted branches with current marker, short tip id, and commit subject. `version branch list --contains REV` is a Git-compatible alias for `version branch contains REV`. `version branch list --merged [BRANCH]` and `version branch list --no-merged [BRANCH]` are Git-compatible aliases for `version branch merged [BRANCH]` and `version branch unmerged [BRANCH]`. `version branch current` prints only the attached branch name and fails on detached HEAD. `version branch exists NAME` is quiet and reports branch existence by exit status. `version branch resolve NAME` prints only the branch tip object id plus a trailing newline. `version branch upstream [BRANCH]` prints the configured upstream as `remote/branch`, defaulting to the current branch when BRANCH is omitted. `version branch contains REV` resolves REV as a commit and prints the sorted branch names whose tips contain that commit. `version branch merged [BRANCH]` prints sorted branch names whose tips are ancestors of the current branch, or of BRANCH when provided. `version branch unmerged [BRANCH]` prints sorted branch names whose tips are not ancestors of the current branch, or of BRANCH when provided.

Common failures: invalid ref name, branch exists/missing, dirty switch target, branch checked out in another worktree, no upstream configured, active integration conflict.

### merge

Syntax: `version merge [OPTIONS] [TARGET...]`, `version merge --continue [--verify|--no-verify]`, `version merge --abort`, `version merge --quit`.

Purpose: merge one or more TARGET revisions into the current branch using the three-way merge engine and persistent conflict state. The content merge performs conservative line-level auto-merges for non-overlapping and independent same-length text edits while preserving one-sided regular-file mode changes, materializes clean symlink additions by attempting host symlink creation when enabled or writing plain link-target files when `core.symlinks=false`, the default engine and selected diff-algorithm modes including explicit Myers add script-based multi-hunk line matching and identical-content/mode-only auto-resolution, synthesizes clean recursive virtual bases for criss-cross histories in the default/recursive engine and rejects multiple merge bases for `-s resolve`, supports similarity-based rename detection with configurable rename limits, opt-in copy-base detection for add/add paths including `find-copies-harder` aliases, and configurable directory-rename application or conflict behavior for additions under a renamed directory including ambiguous split-directory conflicts, same-destination rename/rename including regular-file mode-only changes and rename/add collision staging, records basic side-order-independent rerere preimage/postimage metadata with exact preimage scanning, `rerere.autoupdate` enablement, and replay reuse for rebase/cherry-pick/revert conflicts, and recognizes built-in `merge=ours`, `merge=theirs`, `merge=union`, binary/text merge attributes, and configured external `merge.<name>.driver` commands for blob conflicts from root and nested `.gitattributes` plus `.git/info/attributes`, including `%O`/`%A`/`%B`/`%L`/`%P` and `%S`/`%X`/`%Y` label placeholders with `GIT_DIR`, `GIT_COMMON_DIR`, `GIT_WORK_TREE`, and `GIT_INDEX_FILE` set, with `merge=text` or `!merge` resetting earlier driver rules and `merge.<name>.recursive` honoring built-in `ours`, `theirs`, and `union` or delegating to another configured driver command for virtual-base merges. TARGET may be omitted to merge the configured upstream when `merge.defaultToUpstream` is not false, or may name a branch, tag, remote-tracking ref, full or abbreviated commit id, or supported revision suffix. Supported options include `--ff`, `--ff-only`, `--no-ff`, `--no-commit`, `--squash`, `-m/--message`, `-F/--file`, `--edit`, `--no-edit`, `--log[=<n>]`, `--signoff`, `--cleanup=MODE`, `--stat`, `--no-stat`, `--summary`, `--compact-summary`, `--quiet`, `--verbose`, `--progress`, `--no-progress`, `--autostash`, `--no-autostash`, `-s/--strategy`, `-X ours|theirs|ignore-space-change|ignore-all-space|ignore-space-at-eol|ignore-cr-at-eol|renormalize|no-renormalize|find-renames[=<n>]|renames=<n>|rename-limit=<n>|find-copies[=<n>]|find-copies-harder|copies=<n>|no-copies|no-renames|directory-renames[=true|false|conflict]|no-directory-renames|diff-algorithm=patience|histogram|minimal|myers|subtree[=<path>]|recurse-submodules|no-recurse-submodules`, `--conflict=merge|diff3|zdiff3`, `--marker-size N`, `--renormalize`, `--no-renormalize`, `--find-renames[=<n>]`, `--find-copies[=<n>]`, `--find-copies-harder`, `--rerere-autoupdate`, `--verify`, `--no-verify`, `--verify-signatures`, `--no-verify-signatures`, `--gpg-sign`, `--no-gpg-sign`, `--recurse-submodules`, `--no-recurse-submodules`, and `--allow-unrelated-histories`; `merge.ff`, `merge.autostash`, `merge.autoEdit`, `merge.log`, `merge.stat`/`merge.summary`, `merge.renormalize`, `merge.renames`, `merge.renameLimit`, `merge.directoryRenames`, `branch.<name>.mergeOptions`, `merge.verifySignatures`, `submodule.recurse`, `merge.recurseSubmodules`, `commit.gpgSign`, and `user.signingKey` supply defaults when no explicit option overrides them. `-s resolve` uses the native engine with rename detection disabled, `-s subtree` enables subtree rewriting, `-s octopus` is accepted for multi-target merges but rejected for single-target merges, and explicit two-head strategies are rejected for multi-target merges. `--verify-signatures` verifies target commits through local `git verify-commit`/GPG tooling before mutation; `--gpg-sign[=<key>]` signs created merge commits through local `gpg`, preserving signing intent across `merge --continue` via `MERGE_MODE`. `-Xsubtree=<path>` rewrites the target and merge-base trees below the requested prefix before the three-way merge; bare `-Xsubtree` attempts conservative prefix inference and rejects ambiguous or missing inference. Clean divergent single-target merges create a two-parent merge commit unless `--no-commit` or `--squash` is selected, running `pre-merge-commit` before automatic merge commit creation when hooks are enabled. Clean multi-target merges create a conservative octopus commit; clean multi-target `--squash` writes squash state without advancing `HEAD`, and clean multi-target `--no-commit` writes a multi-line `MERGE_HEAD` plus index state without advancing `HEAD` so `merge --continue` can create the octopus commit. `--autostash` records temporary stash commits in `MERGE_AUTOSTASH`, applies them after successful committed/fast-forward/squash/no-commit merges and abort/continue flows, and stores them on the normal stash stack for quit or when autostash application itself cannot be completed cleanly. Conflicts leave working-tree conflict markers, stage 1/2/3 index entries for unmerged paths, Version merge state, and Git-compatible `MERGE_HEAD`/`MERGE_MSG`/`MERGE_MODE`/`AUTO_MERGE` state for `version merge --continue`, `--abort`, or `--quit`. `version merge --continue` and `version merge --abort` can also consume Git-created conflicted merge state when `MERGE_HEAD`/`ORIG_HEAD` and unmerged index stages are present.

Common failures: detached HEAD, dirty tree, unknown target revision, no merge base without `--allow-unrelated-histories`, active merge/replay state, unresolved conflicts, unsupported strategy or strategy option.

### tag

Syntax: `version tag create NAME`, `version tag create NAME REV`, `version tag create -a NAME -m MESSAGE`, `version tag create -a NAME REV -m MESSAGE`, `version tag delete NAME`, `version tag remove NAME`, `version tag list`, `version tag rename OLD NEW`, `version tag list --points-at REV`, `version tag list --contains REV`, `version tag exists NAME`, `version tag resolve NAME`, `version tag peel NAME`, `version tag show NAME`.

Purpose: manage lightweight and annotated tags. `version tag create NAME` creates a lightweight tag at `HEAD`; `version tag create NAME REV` creates a lightweight tag at a resolved revision. `version tag create -a NAME -m MESSAGE` creates an annotated tag object at `HEAD`; `version tag create -a NAME REV -m MESSAGE` creates an annotated tag object at a resolved revision. `version tag list --points-at REV` is read-only and prints tag names whose peeled target is the resolved revision. `version tag list --contains REV` is read-only and prints tag names whose peeled commit contains the resolved commit revision. `version tag exists NAME` is read-only, prints nothing, and reports tag existence by exit status. `version tag resolve NAME` is read-only and prints only the object id stored in the tag ref, followed by a newline. `version tag peel NAME` is read-only and prints the peeled target id, following annotated tag chains. `version tag show NAME` is read-only and prints stable tag details; annotated tags include the tag object id, peeled target id, target type, and message. `version tag rename OLD NEW` moves a tag ref without rewriting the target object. `version tag delete NAME` and `version tag remove NAME` report the deleted tag ref object id.

Common failures: invalid tag name, duplicate/missing tag, ref transaction failure.

### rebase

Syntax: `version rebase TARGET`, `version rebase -i UPSTREAM`, `version rebase --root --onto NEWBASE`, `version rebase --rebase-merges UPSTREAM`, `version rebase --continue`, `version rebase --abort`.

Purpose: replay current branch commits onto a target with persistent conflict state. `-i`/`--interactive` opens a todo in the sequence editor (`GIT_SEQUENCE_EDITOR`/`GIT_EDITOR`/`EDITOR`) and replays the edited list, supporting **pick, drop, reorder, squash, and fixup**. `--root --onto NEWBASE` replays the whole branch, including its root commit, onto NEWBASE. `--rebase-merges UPSTREAM` replays onto UPSTREAM topologically, recreating two-parent merge commits to preserve branch structure. A plain `TARGET` rebase is limited to non-root, non-merge commits.

Common failures: detached HEAD, dirty tree, merge commit (plain rebase), conflict, active replay state. Interactive `reword`/`edit`/`exec` are not yet supported (squash/fixup and `--rebase-merges` abort rather than pause on conflict); `--rebase-merges` rejects octopus merges; bare `--root` without `--onto`, and `--preserve-merges`, are not supported.

### cherry-pick

Syntax: `version cherry-pick REV`, `version cherry-pick REV...`, `version cherry-pick -m PARENT REV...`, `version cherry-pick --mainline PARENT REV...`, `version cherry-pick --continue`, `version cherry-pick --abort`.

Purpose: apply one or more existing commits onto HEAD. Root commits are applied against an empty base tree. Merge commits require `-m`/`--mainline` with a 1-based parent number.

### revert

Syntax: `version revert REV`, `version revert REV...`, `version revert -m PARENT REV...`, `version revert --mainline PARENT REV...`, `version revert --continue`, `version revert --abort`.

Purpose: create commits that reverse existing commits. Root commits are reversed against an empty parent tree. Merge commits require `-m`/`--mainline` with a 1-based parent number.

Cherry-pick and revert fail on unknown revisions, merge commits without mainline, invalid mainline parents, dirty trees, conflicts, or active incompatible replay state.

### stash

Syntax: `version stash`, `version stash push [PATH...]`, `version stash push --include-untracked [PATH...]`, `version stash push --include-ignored [PATH...]`, `version stash create [PATH...]`, `version stash create --include-untracked [PATH...]`, `version stash create --include-ignored [PATH...]`, `version stash store COMMIT`, `version stash store -m MESSAGE COMMIT`, `version stash list`, `version stash show [--patch] [stash@{N}] [PATH...]`, `version stash apply [stash@{N}] [PATH...]`, `version stash pop [stash@{N}] [PATH...]`, `version stash branch NAME [stash@{N}]`, `version stash drop [stash@{N}]`, `version stash clear`.

Purpose: save and restore uncommitted work through `refs/stash`. Pathspecs on `stash push` limit the stashed and reset paths; non-matching changes are left in the working tree/index. `--include-untracked` adds non-ignored untracked files; `--include-ignored` adds both non-ignored and ignored untracked files. `stash create` writes a stash-shaped commit and prints its id without updating `refs/stash` or resetting the worktree; `stash store COMMIT` validates and pushes such a commit onto the stash stack using the stored commit subject as the list message; `-m MESSAGE` overrides that message. `stash show` lists stashed paths, and `stash show --patch` prints the patch; optional pathspecs filter summary, patch, apply, and pop output/effects; no-match apply/pop reports that no paths matched and leaves the stash stack unchanged. `stash branch` creates a branch at the stash base, switches to it, applies the selected stash, and drops that stash only after a successful apply. `stash clear` removes the entire stash stack.

Common failures: dirty target blocks apply/pop/branch, existing branch target, invalid stash spec, missing stash, active replay state, conflict during apply.

## Remotes and transports

### remote

Syntax: `version remote add NAME URL`, `version remote delete NAME`, `version remote remove NAME`, `version remote list`, `version remote get-url NAME`, `version remote exists NAME`, `version remote set-url NAME URL`, `version remote rename OLD NEW`, `version remote prune NAME --dry-run`, `version remote prune NAME`.

Purpose: manage configured remotes.

`version remote list` is read-only and prints one stable tab-separated `name<TAB>url` row per configured remote. Clean repositories with no remotes print no output.

`version remote get-url NAME` is read-only and prints only the configured URL for one remote, followed by a newline.

`version remote exists NAME` is a quiet predicate: it prints nothing, exits successfully when the remote exists, and exits with command failure when it is absent.

`version remote set-url NAME URL` updates the configured URL for an existing remote. It does not create a missing remote and preserves the existing fetch refspec.

`version remote rename OLD NEW` renames an existing remote. It rejects a missing source remote, rejects destination-name collisions, preserves the configured URL, and keeps the existing fetch refspec unchanged.

`version remote prune NAME --dry-run` compares local remote-tracking refs against the remote advertised branch refs and prints stale refs as `would prune NAME/BRANCH` lines without deleting anything. `version remote prune NAME` performs the same stale-ref detection, deletes those stale remote-tracking refs, and prints `pruned NAME/BRANCH` lines. Local, `file://`, HTTP(S), and configured SSH remotes use their normal advertised-ref discovery paths.

Common failures: invalid name, unsupported URL scheme, duplicate/missing remote, remote discovery failure, SSH subprocess failure.

### fetch

Syntax: `version fetch REMOTE`, `version fetch --depth N REMOTE`.

Purpose: fetch objects and refs from a remote.

Common failures: missing remote, unsupported transport, protocol/pack failure, unsupported shallow request.

### push

Syntax: `version push REMOTE`, `version push REMOTE BRANCH`, `version push --no-verify REMOTE BRANCH`, `version push --force REMOTE BRANCH`, `version push --delete REMOTE REF`, `version push REMOTE SRC:DST`, `version push REMOTE +SRC:DST`, `version push REMOTE :DST`, `version push --tags REMOTE`, `version push REMOTE --tags`, `version push --no-verify --tags [REMOTE]`.

Purpose: push or delete refs on a remote. Branch and tag push both support local, `file://`, HTTP(S), and SSH remotes. By default a branch update must fast-forward the remote; `--force` (or `-f`) permits a non-fast-forward update. Tag push refuses to overwrite a differing existing remote tag unless `--force` is also given (`push --tags --force`). `--delete` (or `-d`) removes a remote ref (`REF` is a branch name, or a full `refs/...` ref such as `refs/tags/v1`); it cannot be combined with `--tags` or `--force`. A refspec `SRC:DST` pushes the commit named by `SRC` to remote ref `DST` (a branch name or full `refs/...` ref); a leading `+` forces a non-fast-forward update, and an empty `SRC` (`:DST`) deletes `DST`. With no refspec (`push REMOTE`), the configured `remote.<REMOTE>.push` refspec(s) are applied (each parsed like a command-line refspec); it errors if none are configured.

Common failures: missing remote, no refspec given and `remote.<name>.push` not configured, rejected update, remote branch or tag changed during push, non-fast-forward without `--force`, refusing to overwrite a differing remote tag, deleting a ref that does not exist on the remote, unsupported transport, pre-push hook failure.

## Sparse, worktree, and submodule

### sparse

Syntax: `version sparse init`, `version sparse set PATHSPEC...`, `version sparse add PATHSPEC...`, `version sparse list`, `version sparse status`, `version sparse disable`.

Purpose: keep only selected tracked paths materialized.

Common failures: dirty tree, unborn branch, unsafe deletion/materialization target, invalid pathspec.

### worktree

Syntax: `version worktree add PATH BRANCH`, `version worktree add --detach PATH REV`, `version worktree list`, `version worktree current`, `version worktree remove PATH`.

Purpose: manage linked worktrees with shared objects/refs and isolated HEAD/index/sparse/replay state.

`version worktree list` prints one stable line per known worktree using marker brackets: `[current primary]` for the current primary worktree, `[linked branch-in-use]` for a linked branch worktree, `[linked detached]` for detached linked worktrees, and `[linked missing branch-in-use]` when linked metadata remains but the worktree path is missing. Branch lines end with `branch NAME`; detached lines end with `detached SHORTOID`. `version worktree current` prints the same stable single-line shape for only the current worktree, using `[current primary]` or `[current linked]` to distinguish the current repository layout.

Common failures: branch already checked out elsewhere, target exists, dirty removal target, invalid common-dir or backlink metadata.

### submodule

Syntax: `version submodule init`, `version submodule update [--recursive]`, `version submodule status`.

Purpose: initialize, update, and inspect supported Git-compatible submodules.

`version submodule status` prints one stable line per active submodule. The leading marker matches the Git-style status class and is followed by an explicit label: ` ` means clean, `-` means missing or not checked out, `+` means the submodule HEAD is at a different commit than the gitlink, and `!` means the submodule worktree is dirty. Sparse-excluded submodule paths are omitted from this report.

Common failures: malformed `.gitmodules`, unsafe path, relative URL without a configured superproject remote, unsupported resolved URL, missing gitlink object, checkout preflight failure.

## Archive export

### archive

Syntax: `version archive REV`, `version archive REV --output PATH`, `version archive REV --format tar|zip`, `version archive REV [--] PATHSPEC...`.

Purpose: export the tree referenced by `REV` directly from repository objects without reading the working tree, index, sparse checkout materialization, or linked-worktree state.

Default output is `archive.tar`. `--format zip` defaults to `archive.zip`; format names are accepted case-insensitively. An explicit `--output release.zip` selects ZIP when `--format` is omitted; otherwise TAR remains the default. Output suffixes for unsupported compressed/proprietary formats such as `.tar.gz`, `.tgz`, `.gz`, `.tar.xz`, `.txz`, `.xz`, `.tar.bz2`, `.tbz`, `.tbz2`, `.bz2`, `.zipx`, `.7z`, and `.rar` are rejected even when `--format` is supplied, because this phase does not emit compressed TAR or proprietary archives. Unknown `--long-option` values are rejected before `--`; pathspecs that intentionally start with `--` must follow the `--` separator.

Supported formats are `tar` and `zip`. ZIP file entries use the integrated Ada Zlib stored-deflate path. Unsupported compressed or proprietary formats such as `tar.gz`, `tgz`, `tar.xz`, `tar.bz2`, `zipx`, `7z`, and `rar` are rejected.

Pathspecs filter exported entries after revision/tree resolution. Exclusion-only pathspecs are supported; a no-match filter produces a valid empty archive for the selected format. Submodule gitlinks are exported as small placeholder files containing the gitlink commit id rather than recursively archiving the submodule. Git symlinks are emitted as symlink metadata in TAR/ZIP instead of being flattened as regular files.

Common failures: unknown revision, invalid pathspec, unwritable output path, output path naming a directory, invalid tree object, unsupported format, unsafe archive entry path, unsafe archive prefix component, or archive path too long for the selected format. Unsupported-format diagnostics name `tar` and `zip` as the supported formats.

## `version doctor`

```sh
version doctor
version doctor --release
```

`version doctor` checks the current repository shape, supported object format, readable `HEAD`, and readable index without mutating repository state.

`version doctor --release` is a source-tree convenience command that runs the local release gate scripts. It is intended for developer ergonomics only; release certification still requires the full AUnit and platform CI evidence gates.

## Command unavailable diagnostics

Commands that cannot run because a precondition is missing should fail before mutation with a precise `error: ...` diagnostic. The stable precondition classes are:

- `no repository found: run 'version init' or move into a working tree`
- `no active branch: HEAD is detached or unborn`
- `no staged changes to save`
- `no remote configured: NAME`
- `no upstream configured for branch: NAME`
- `repository format unsupported: DETAIL`
- `operation unsafe in linked worktree: OPERATION`
- `path is outside worktree: PATH`
- `path is outside sparse checkout: PATH`
- `branch already checked out in another worktree: NAME`

These diagnostics are part of the CLI freeze surface and are tested through the centralized `Version.Availability` helper.
