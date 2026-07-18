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

Commands accepting `PATHSPEC...` support repository-relative literal paths, directory prefixes, `*`, `?`, recursive `**`, exclusions with `:!` or `:^`, top-anchored `:/path`, and long magic forms `:(literal)`, `:(glob)`, `:(top)`, `:(icase)` (case-insensitive match), and `:(exclude)`. Pathspecs filter command-owned candidates; they do not grant filesystem access outside the repository. Backslash separators are rejected with a stable diagnostic; use `/` in repository-relative pathspecs on every platform.

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

If the remote's HEAD points to a branch that was not fetched (a dangling remote HEAD — e.g. a bare repository whose configured default branch was never pushed), clone matches `git clone`: it warns `remote HEAD refers to nonexistent ref, unable to checkout` and completes successfully with HEAD pointing at the (unborn) default branch — the remote branches are still fetched, but nothing is checked out and no `refs/remotes/origin/HEAD` is written.

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

### maintenance

Syntax: `version maintenance run [--task=<task>] [--quiet] [--auto]`.

Purpose: run repository maintenance, matching `git maintenance run`. Succeeds silently. With no `--task` (or `--task=gc`/`loose-objects`/`incremental-repack`) it runs version's garbage collection; the auxiliary tasks `commit-graph`, `pack-refs`, and `prefetch` are accepted but no-ops (version does not keep those files). An unknown `--task` is rejected with `error: '<task>' is not a valid task`. The scheduling subcommands `start`, `stop`, `register`, and `unregister` are intentionally unsupported — they manage OS cron/systemd units rather than repository data.

Common failures: not in a repository, unknown task, unknown option.

### check-ref-format

Syntax: `version check-ref-format [--normalize] [--allow-onelevel] [--no-allow-onelevel] [--refspec-pattern] <refname>`, `version check-ref-format --branch <name>`.

Purpose: validate a refname against git's grammar, matching `git check-ref-format` — exit 0 when valid, 1 otherwise. A conforming name needs at least one `/` (waived by `--allow-onelevel`); no component may begin with `.` or end with `.lock`; the name may not contain `..`, `@{`, ASCII control characters, space, or any of `~ ^ : ? * [ \`, may not begin or end with `/`, and may not end with `.`. `--refspec-pattern` permits a single `*` glob. `--normalize` drops a leading `/` and collapses runs of `/`, printing the result when it is valid. `--branch <name>` prints the resolved branch name (`@{-N}` is resolved through the HEAD reflog) and exits non-zero when it is not a valid branch name.

Common failures: an invalid refname (exit 1), too few branch switches for `@{-N}`.

### stripspace

Syntax: `version stripspace [-s|--strip-comments | -c|--comment-lines]`.

Purpose: clean up a message read from stdin, matching `git stripspace`. By default it strips trailing whitespace from each line, collapses runs of blank lines into one, removes leading and trailing blank lines, and newline-terminates a non-empty result. `-s`/`--strip-comments` additionally removes lines whose first character is `#`. `-c`/`--comment-lines` instead prefixes every line with `# ` (a bare `#` for an empty line) and performs no other cleanup. `-s` and `-c` are mutually exclusive.

Common failures: unknown option.

### interpret-trailers

Syntax: `version interpret-trailers [--trailer <token>=<value>...] [--where after|before] [--only-trailers] [--only-input] [--unfold] [--parse] [--in-place] [<file>...]`.

Purpose: add or extract commit-message trailers, matching `git interpret-trailers`. Reads the message from stdin (or each `<file>`, writing back with `--in-place`). A trailer block is the last blank-line-delimited paragraph, provided it is not the only paragraph and contains at least one `token: value` line. `--trailer` appends new trailers into that block (creating one after a blank line if absent); `--where before` inserts before the existing trailers instead of after. Both `:` and `=` are accepted as the argument separator and normalise to `: `. `--only-trailers` emits just the trailer block, `--unfold` joins continuation lines, and `--parse` is `--only-trailers --only-input --unfold`. `--only-input` may not be combined with `--trailer`.

Common failures: unreadable file operand, `--trailer` combined with `--only-input`, unknown option.

### hook

Syntax: `version hook run [--ignore-missing] <hook-name> [-- <args>...]`.

Purpose: run a repository hook by name, matching `git hook run`. Arguments after `--` are passed to the hook; the hook's stdout and stderr stream through unchanged and its exit code becomes `version`'s. A missing (or non-executable) hook reports `error: cannot find a hook named <hook-name>` and exits 1, unless `--ignore-missing` is given (then it is a silent no-op with exit 0).

Common failures: not in a repository, missing hook name, missing hook without `--ignore-missing`.

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

Purpose: print local repository config entries in stable `section.key=value` form, print only flattened config keys, print the value for one local config key, quietly test whether a key exists, set one local config key, or remove one local config key. Quoted subsections are rendered as dotted names, for example `remote.origin.url=...` and `branch.main.merge=refs/heads/main`; section and variable names are lower-cased (subsection case preserved) as git canonicalises them. When reading the effective config, `list`/`keys`/`get` read git's full scope stack in order — system (`/etc/gitconfig` or `GIT_CONFIG_SYSTEM`, unless `GIT_CONFIG_NOSYSTEM`), global (`$XDG_CONFIG_HOME/git/config` then `~/.gitconfig`, or `GIT_CONFIG_GLOBAL` replacing both), then the repository's local `.git/config` and per-worktree `config.worktree` — and follow `[include]` and matching `[includeIf "gitdir:...|gitdir/i:...|onbranch:...|hasconfig:remote.*.url:..."]` directives (the include `path` resolves relative to the including file, with `~` expansion; the directive itself stays a readable key such as `include.path`). A single-valued `get` resolves to the last matching value in read order — matching git. The inspection commands are read-only. Config injected via `GIT_CONFIG_COUNT`/`GIT_CONFIG_KEY_<n>`/`GIT_CONFIG_VALUE_<n>` is not yet consulted. Writes (`set`/`unset`) still target only the local `.git/config`. `version config has KEY` prints nothing, exits successfully when the key exists, and exits with command failure when the key is absent. `version config set KEY VALUE` creates or updates the selected key in local `.git/config` using deterministic rewrite semantics. `version config unset KEY` rewrites the local config without the selected key and preserves unrelated entries.

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

Syntax: `version status [--porcelain[=v1]|--short|--long] [--branch] [-z] [--ignored[=traditional|matching|no]] [-u|-uall|-uno|--untracked-files[=normal|all|no]] [--] [PATHSPEC...]`.

Purpose: show deterministic working-tree, index, untracked, and optionally ignored status. `--porcelain` and its `--short` alias print the same stable project-specific machine-readable subset. `--branch` is a modifier, as in git -- it may be combined with `--short` or `--porcelain` -- and prepends a stable `## branch` header, including upstream/ahead/behind details when configured, before those same short entries: `S <A|M|D> path` for staged changes, `W <A|M|D> path` for working-tree changes, `? A path` for untracked files, and `! ! path` for ignored paths when requested. `-z` terminates each machine-readable record with NUL instead of a newline, and `-uno` omits untracked files entirely. `--ignored` can combine with long, porcelain, short, or branch output; `--ignored=traditional` lists ignored files, `--ignored=matching` reports ignored directories that match a rule as directories, and `--ignored=no` disables ignored output. Clean porcelain status prints no output. A directory containing nothing but untracked files is reported as `dir/` rather than file by file, as git does; `-uall`/`--untracked-files=all` lists every untracked file. A mode-only change (for example `chmod +x` on an otherwise unchanged file) is reported as a modification. A staged delete and add whose contents are identical or at least 50% similar are reported as one rename (`R  old -> new`, or `RM` when the destination is also modified in the working tree); `status.renames=false` disables this. The shorthand phrases `status --porcelain` and `status --short` refer to this stable subset. The default long format is git's: `On branch <name>` (or `HEAD detached at <abbrev>`), the tracking lines when the branch has an upstream, a `No commits yet` block before the first commit, a `You have unmerged paths.` block during a conflicted merge, then the `Changes to be committed:`, `Unmerged paths:`, `Changes not staged for commit:`, `Untracked files:` and `Ignored files:` sections with git's hints, tab-indented entries whose label is padded to git's column, and git's closing summary line.

Common failures: repository discovery failure, malformed index, unsafe repository path.

### check-ignore

Syntax: `version check-ignore [-q|--quiet] [-v|--verbose] [--stdin] [-z] [-n|--non-matching] [--index|--no-index] [--] PATH...`.

Purpose: test path operands against the repository ignore rules loaded from `core.excludesFile`, `.git/info/exclude`, and `.gitignore` files. By default the command honors the index, prints each ignored untracked operand in input order, omits non-matching operands, exits successfully when any operand is ignored, and exits with the command-failure status when none are ignored. `-q` and `--quiet` suppress output while preserving that predicate exit status. `-v`/`--verbose` prints `source:line:pattern<TAB>path` for paths matched by an ignore rule, including negations; with `-n`/`--non-matching`, unmatched operands are printed as empty source/line/pattern fields. `-z` switches output records to NUL delimiters; with `--stdin`, input is NUL-delimited too. `--no-index` checks tracked paths against ignore rules; `--index` restores the default index-honoring behavior when both are present.

Common failures: missing path operand, repository discovery failure, malformed ignore/config data.

### diff

Syntax: `version diff [OPTIONS] [--] [PATHSPEC...]`, `version diff [OPTIONS] --staged [--] [PATHSPEC...]`, `version diff [OPTIONS] --cached [--] [PATHSPEC...]`, `version diff [OPTIONS] REV1 REV2`, `version diff [OPTIONS] REV`.

Options: `--stat`, `--name-only`, `--name-status`, `-U<n>`/`--unified=<n>`, `-M`/`-M<n>`/`--find-renames[=<n>]`, `--no-renames`.

Purpose: show working-tree, staged, or commit-to-commit differences. The output is a minimal git-format unified diff (Myers/LCS hunks with context, a `diff --git` header, and an `index <old>..<new> <mode>` line; new/deleted/binary files and no-newline-at-EOF are rendered as git does). `--cached` is a byte-identical alias for `--staged`. `--stat` replaces the patch with git's per-file change-bar summary and a `N files changed, ...` footer.

Renames are detected by default, as in git: a deleted path and a created path with similar enough content are reported as one rename (`similarity index NN%` plus `rename from`/`rename to` in the patch, `a => b` or the brace-compressed `d/{a => b}` in `--stat`, `R<nnn>` with both paths in `--name-status`). The similarity threshold defaults to 50% and is set with `-M<n>` (`-M75%`, or git's fractional spelling where `-M9` means 90%); `--no-renames` turns detection off, and the `diff.renames` configuration selects the default.

Common failures: unknown revision, malformed object, no eligible paths.

### restore

Syntax: `version restore`, `version restore [--] PATHSPEC...`, `version restore --staged [--] PATHSPEC...`, `version restore --source REV [--] PATHSPEC...`, and staged/source combinations.

Purpose: restore working-tree or staged paths from HEAD or another revision.

Common failures: unknown source revision, dirty target, no source match, filesystem-guard rejection.

### checkout

Syntax: `version checkout REV`, `version checkout REV -- PATHSPEC...`.

Purpose: detach at a revision or restore matching paths from a revision.

Common failures: unknown revision, dirty working tree, unsafe materialization target.

### switch

Syntax: `version switch [-c|-C <new-branch>] [--detach] (<branch>|<start-point>|-)`.

Purpose: switch the current branch, matching `git switch`. `<branch>` updates HEAD to the branch symref (`Switched to branch '<name>'`); `-c`/`-C <new> [<start>]` creates `<new>` (at `<start>`, else HEAD) and switches to it (`Switched to a new branch '<new>'`); `-` returns to the previously checked-out branch (resolved from the HEAD reflog); `--detach [<commit>]` detaches HEAD at `<commit>` (default HEAD) and prints `HEAD is now at <short> <subject>`. Leaving a detached HEAD first prints `Previous HEAD position was <short> <subject>`, as git does.

Common failures: unknown branch or revision, no previous branch for `-`, ambiguous or missing operand.

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

Syntax: `version clean [-n] [-f] [-d] [-x] [--] [PATHSPEC...]`.

Purpose: remove untracked files from the working tree. `-d` also removes untracked directories (reported collapsed, like git); `-x` also removes ignored files. `-n` previews (`Would remove ...`); one of `-n` or `-f` is required (clean refuses otherwise). Short flags may be combined (e.g. `-fd`).

Pathspecs limit which untracked paths are considered; without any, clean still limits itself to the directory it was run in, as git does, and reports paths from there.

Common failures: neither `-n` nor `-f` given (refuses to clean).

### bundle

Syntax: `version bundle create FILE REF...`, `version bundle verify FILE`, `version bundle list-heads FILE`.

Purpose: offline transport. `create` writes a v2 bundle (header plus a packfile of all objects reachable from the given refs; `REF` may be a branch name, `HEAD`, or `--all`). `verify` checks a bundle and lists its refs; `list-heads` prints its `<oid> <refname>` lines. Bundles produced here can be cloned/fetched by `git`, and git's bundles are read here.

Common failures: unrecognized ref, not a git bundle file.

### apply

Syntax: `version apply [--check] [-R|--reverse] [-p<n>] [--index] [--cached] [PATCHFILE]`.

Purpose: apply a unified diff to the working tree and/or index (reading PATCHFILE, or standard input when omitted). Handles modify, create (`--- /dev/null`), delete (`+++ /dev/null`), pure **rename** (`rename from`/`rename to`), **mode-only** (`old mode`/`new mode`) and **git binary** patches (`GIT binary patch`, literal or delta, base85+zlib). `-p<n>` strips `n` leading path components (default 1); `-R`/`--reverse` applies the patch backwards; `--index` updates both the working tree and the index, `--cached` updates only the index. The patch is validated in full before any change (`--check` stops after validation).

Common failures: malformed patch, context/deletion mismatch (patch does not apply). Not yet supported: `-R`, `-p` other than 1, `--index`/`--cached`, fuzz, binary patches, rename/mode-only patches.

### format-patch

Syntax: `version format-patch [--stdout] [-o DIR] (REVISION | -<n>)`.

Purpose: write one mbox patch file per commit in REVISION's range, oldest first (`<since>` means `<since>..HEAD`; `<A>..<B>` is an explicit range; `-<n>` is the last n non-merge commits ending at HEAD, or at REVISION when one is given, and stops at the root commit if the history is shorter). `--stdout` writes all patches to standard output; `-o DIR` selects the output directory (default: current). Output (RFC2822 author date, `[PATCH n/m]` subjects) is consumable by `git am`. A binary change is written as git's `GIT binary patch` (base85-encoded deflate, forward and reverse), so binary commits apply cleanly; the compressed bytes are not expected to equal git's, only to decode identically.

Common failures: unknown revision.

### am

Syntax: `version am [MBOX...]`, `version am --continue`, `version am --skip`, `version am --abort`.

Purpose: apply patches from one or more mbox files (as written by `format-patch`, or standard input when none are given), committing each on the current branch with its recorded author (name/email/date) and message. When a patch does not apply, the session stops with the remaining patches recorded under `.git/rebase-apply` and a resolution hint. Resolve the conflict and `--continue` (commit the staged result with the patch's authorship and resume), `--skip` (drop the patch and resume), or `--abort` (reset HEAD, index and working tree to where the session started).

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

Syntax: `version grep [-n] [-i] [-w] [-v] [-E|-F|-G|-P] PATTERN [--] [PATH...]`.

Purpose: search the working-tree content of tracked files for PATTERN, printing `path:text` (or `path:line:text` with `-n`). PATTERN is a **regular expression** — basic (`-G`, the default), extended (`-E`), fixed string (`-F`), or perl-style (`-P`, treated as extended). `-i` ignores case, `-w` matches whole words, `-v` inverts (lines that do not match). Trailing `PATH` arguments (pathspecs, after an optional `--`) limit the search. Exits non-zero when nothing matches. (The basic/extended distinction follows POSIX: in the default basic mode `+ ? | ( ) { }` are literal unless backslash-escaped.)

### describe

Syntax: `version describe [REV]`.

Purpose: name REV (default HEAD) relative to the nearest reachable tag — the tag itself when exactly tagged, otherwise `<tag>-<N>-g<short>`.

### notes

Syntax: `version notes add [-f|--force] -m MSG [REV]`, `version notes show [REV]`.

Purpose: attach or show a text note on a commit (default HEAD), stored in refs/notes/commits. Notes are written flat (one entry per commit id), which git reads. As git does, `add` refuses to replace an existing note unless `-f`/`--force` is given.

### blame

Syntax: `version blame [REV] FILE`.

Purpose: show, for each line of FILE at REV (default HEAD), the abbreviated commit that introduced it. Attribution uses git's **line-tracking** approach: each version of the file is diffed against its first parent (common prefix/suffix plus a longest-common-subsequence match on the middle), unchanged lines are followed up the history, and a line is blamed to the commit that first introduced it at that position — so duplicate and re-added lines are attributed correctly. Merges are followed along the first parent.

## Plumbing

Low-level commands over the object/ref/index store, intended for scripts. Output matches `git`'s for the supported forms.

- `version cat-file (-t|-s|-e|-p|blob|tree|commit|tag) OBJECT` — object type, size, existence (exit status), or pretty content (`-p` of a tree lists entries recursively). The `<type> <object>` form prints the contents and fails if the object is not of that type.
- `version rev-parse [--abbrev-ref] [--short] [--symbolic-full-name] [--verify] [--quiet|-q] [--all] [--revs-only] [--show-toplevel] [--show-prefix] [--git-dir] [--absolute-git-dir] [--is-inside-work-tree] [--is-bare-repository] REV...` — resolve revisions to object ids (or the branch name for `--abbrev-ref HEAD`, the full ref for `--symbolic-full-name`). `--verify --quiet` exits 1 without a message when a revision does not resolve; `--all` lists every ref's object id; the repository-location queries report the paths git reports.
- `version ls-files [-s|--stage] [-o|--others] [-m|--modified] [-d|--deleted] [--exclude-standard] [--] [PATHSPEC...]` — list tracked (stage-0) index paths, optionally filtered by pathspecs.
- `version ls-tree [-r] [--name-only] TREE-ISH [--] [PATH...]` — list a tree's entries; one level by default (subtrees shown as `tree` entries), recursively with `-r`. Paths select entries.
- `version hash-object [-w] [--stdin] [FILE]` — compute (and with `-w` write) a blob id.
- `version write-tree` — write the index as a tree and print its id.
- `version mktree [--missing]` — read `<mode> <type> <sha> TAB <path>` entries on stdin, sort them into git tree order, write the tree object, and print its id; referenced objects must exist unless `--missing`.
- `version mktag` — read a tag object on stdin, validate its `object`/`type`/`tag`/`tagger` header (and that the referenced object exists with the declared type), write it verbatim, and print its id.
- `version fmt-merge-msg [-F <file>]` — format a merge-commit message from FETCH_HEAD (read on stdin, or from `-F <file>`), grouping merged branches/tags by source and appending ` into <branch>` off the default branch.
- `version get-tar-commit-id` — read a tar archive on stdin and print the commit id recorded in its pax global header (`version archive REV` writes this header when REV is a commit); exits non-zero when no id is present.
- `version diff-tree [-r] [--root] (<tree> <tree> | <commit>)` — raw diff between two trees, or a commit against its parent (`--root` diffs a root commit against the empty tree); `-r` recurses into subtrees. Prints `:<mode1> <mode2> <sha1> <sha2> <status>\t<path>` lines (the single-commit form prints the commit id first).
- `version diff-index [--cached] <tree-ish>` — raw diff of a tree against the index (`--cached`) or the working tree.
- `version diff-files` — raw diff of the index against the working tree.
- `version replace [-f] <object> <replacement>` / `replace -d <object>...` / `replace [-l] [--format=short|medium|long] [<pattern>]` — create, delete, or list `refs/replace/*` entries. Object reads follow the replacement (set `GIT_NO_REPLACE_OBJECTS` to bypass). `--format=medium` prints `<object> -> <replacement>`, `--format=long` adds each object's `(type)`.
- `version bisect start [--term-old <t> --term-new <t>] [<bad> [<good>...]]` / `bisect (good|bad|new|old|<term>) [<rev>...]` / `bisect skip [<rev>...]` / `bisect reset [<commit>]` / `bisect log` / `bisect terms [--term-good|--term-bad]` — binary-search history for the first bad commit. Manages `refs/bisect/*`, `BISECT_START`, `BISECT_TERMS`, and `BISECT_LOG`; at each step it checks out the computed midpoint (`Bisecting: N revisions left to test after this (roughly M steps)`) and, once the range collapses, prints `<oid> is the first bad commit` followed by that commit's `--stat` summary. Commit selection, the revisions-left/steps counts, the log format, and the reset transcript are byte-identical to `git bisect`. `bisect run <command> [<arg>...]` tests each commit by running the command, taking its exit status as the verdict (0 good, 125 skip, 1..127 bad, 128 and above aborts), and prints git's transcript byte for byte. (`replay`/`visualize` are not yet implemented; `skip` records state and logs like git but may pick a different next commit to test when the choice is tied.)
- `version show-branch [--list] [<branch>...]` — git's branch-comparison matrix: a header naming each branch tip (`*` current / `!` others), an N-dash separator, then one `*`/`+`/`-`/space marker column per branch for every commit back to the branches' merge base, each labelled by first-parent distance (`ref`/`ref^`/`ref~n`). No operands compares all local branches (alphabetically); `--list` prints only the head summary. Byte-identical to git for non-merge ranges (merge commits inside the range are not yet modelled).
- `version merge-file [-p] [-q] [-L <label>]... [--diff3|--zdiff3] [--ours|--theirs|--union] [--diff-algorithm=<algo>] [--marker-size=<n>] <current> <base> <other>` — hunk-level 3-way merge of `<current>` and `<other>` against `<base>`, matching `git merge-file`. Clean hunks merge silently; conflicts get `<<<<<<<`/`=======`/`>>>>>>>` markers (plus `|||||||` base with `--diff3`/`--zdiff3`). `--ours`/`--theirs`/`--union` resolve conflicts; `-L` sets marker labels; `--diff-algorithm=` selects `myers` (the default here), `minimal`, `patience`, or `histogram`; `--marker-size` widens markers. Writes to `<current>` unless `-p`; exit status is the conflict count. Like git, `merge-file` combines conflicts a little more eagerly than `merge` does: as well as gaps of at most three common lines, it folds in any gap whose lines carry no letter or digit.
- `version difftool [--tool=<tool>] [-y|--no-prompt] [--cached|--staged]` — run the tool configured by `diff.tool` and `difftool.<tool>.cmd` once per changed path, with `$LOCAL` (the committed blob), `$REMOTE`/`$MERGED` (the working file) and `$BASE` in the environment.
- `version mergetool [--tool=<tool>] [-y|--no-prompt]` — run the tool configured by `merge.tool` and `mergetool.<tool>.cmd` once per conflicted path, with `$BASE`/`$LOCAL`/`$REMOTE` written from index stages 1/2/3 and `$MERGED` the working file. Keeps the conflicted file as `<path>.orig` and stages the path when the tool exits 0.
- `version http-fetch [-a] [-v] [-w <name>] <commit> <url>` — fetch everything reachable from `<commit>` over the dumb HTTP protocol (plain GETs; a server with no git on it). `-w <name>` writes the commit id into `$GIT_DIR/refs/<name>`.
- `version repo info [--all|-z] [<key>...]` — `layout.bare`, `layout.shallow`, `object.format` and `references.format`, as `key=value`.
- `version repo structure` — the repository's reference counts, in git's table. (git's object-count and size sections are not implemented; `git repo` is an experimental command, so it is not a parity target.)
- `version multi-pack-index write|verify` — write (or check) `.git/objects/pack/multi-pack-index`, one lookup table over every pack. Byte-identical to git's, except that two packs written within the same second may have a duplicated object attributed to the other one (git compares sub-second mtimes).
- `version commit-graph write|verify` — write (or check) `.git/objects/info/commit-graph`, the cache of the history's shape. The file is byte-identical to git's, EDGE chunk for octopus merges included.
- `version backfill` — fetch the blobs a partial clone is still missing from the promisor remote.
- `version filter-branch [-f] [--index-filter <cmd>] [--tree-filter <cmd>] [--msg-filter <cmd>] [--subdirectory-filter <dir>] [--prune-empty] [<rev>]` — rewrite history. Each commit's author and committer survive; the pre-rewrite tip is kept under `refs/original/`, and `-f` is needed to overwrite an existing backup.
- `version last-modified [<rev>] [-- <path>...]` — for each entry of the tree (a directory counts as one entry), the last commit that changed it, as `<oid> TAB <path>`.
- `version refs list|verify` — list the refs (`<oid> <type> TAB <ref>`), or check that each names an object that is there. `refs migrate` is refused: version has only the files backend.
- `version diff-pairs -z` — read raw diff records (`diff-tree -z` output) on stdin and write the corresponding patches.
- `version fetch-pack [--all] <repository> [<ref>...]` — fetch the objects the named refs need without updating any local ref, printing `<oid> <ref>` for each.
- `version send-pack [--force] <repository> <refspec>...` — push refs to a repository named by path or URL (no configured remote needed).
- `version fast-export [--all] [<ref>...]` — write the history as a fast-import stream (blobs, commits with their marks, resets and annotated tags).
- `version fast-import` — read a fast-import stream on stdin and build the objects and refs it describes.
- `version mailsplit [-o<directory>] [<mbox>...]` — split an mbox (or stdin) into one numbered file per message and print how many.
- `version mailinfo <msg> <patch>` — read one mail from stdin, print its `Author:`/`Email:`/`Subject:`/`Date:`, and write its commit message to `<msg>` and its patch to `<patch>`.
- `version index-pack [--stdin] [-o <idx-file>] [<pack-file>]` — build a pack's `.idx` and print the pack's checksum. With `--stdin` the pack is read from stdin and stored under `.git/objects/pack/`.
- `version unpack-objects [-n|--dry-run] [-q]` — read a pack from stdin and write every object in it out as a loose object.
- `version pack-objects [--stdout] [<base-name>]` — read object ids from stdin and write a pack, either to `<base-name>-<checksum>.pack` (+ `.idx`, printing the checksum) or to stdout. version writes undeltified packs: git reads and verifies them, but their bytes differ from a pack git would have written.
- `version merge-index [-o] [-q] <merge-program> (-a | [--] <file>...)` — run a per-path merge program over the index's unmerged paths. `merge-one-file` is built in; any other program is spawned with git's seven arguments.
- `version merge-one-file <orig blob> <our blob> <their blob> <path> <orig mode> <our mode> <their mode>` — merge one path three ways, updating the index and the working tree. Ids and modes are empty for a side that does not have the file.
- `version merge-ours|merge-recursive|merge-recursive-ours|merge-recursive-theirs|merge-subtree|merge-resolve|merge-octopus <base>... -- <head> <remote>...` — the merge-strategy backends. They merge into the index and working tree and do not commit.
- `version merge-tree --write-tree [--name-only] [-z] [--messages|--no-messages] [--merge-base=<commit>] <commit1> <commit2>` — merge two commits without touching the working tree or the index. Prints the merged tree's object id; on conflict it also prints each conflicted path's stage 1/2/3 index entries, a blank line, and the merge messages, and exits 1.
- `version show-index [--object-format=<fmt>]` — read a pack index on stdin and list `<offset> <sha> (<crc32>)` per object.
- `version unpack-file <blob>` — write the blob's contents to a temporary file and print its name.
- `version prune-packed [-n|--dry-run] [-q|--quiet]` — delete the loose objects that are already in a pack.
- `version ls-remote [--heads] [--tags] [--exit-code] [<repository>] [<pattern>...]` — list the refs a remote advertises (`<oid> TAB <ref>`), HEAD first and an annotated tag followed by its peeled `^{}` entry. `--exit-code` exits 2 when nothing matched.
- `version check-attr [-a|--all] [--] <attr>... <pathname>...` — the `.gitattributes` attributes a path has, as `<path>: <attr>: set|unset|unspecified|<value>`.
- `version check-mailmap <contact>...` — the canonical identity `.mailmap` maps each `Name <email>` to.
- `version for-each-repo --config=<key> [--] <command>...` — run a `version` command in every repository the configuration key lists.
- `version subtree add --prefix=<dir> <commit>` / `version subtree add --prefix=<dir> <repository> <ref>` — graft a foreign history into `<dir>` as a merge commit (`--squash` collapses it to a single synthetic commit; `-m` sets the message).
- `version subtree merge --prefix=<dir> <commit>` / `version subtree pull --prefix=<dir> <repository> <ref>` — merge a new state of the subtree into `<dir>` (`merge --no-ff -Xsubtree=<dir>`), fetching first in the `pull` form.
- `version subtree split --prefix=<dir> [<rev>] [-b <branch>] [--onto=<commit>] [--rejoin] [--ignore-joins]` — extract `<dir>`'s history as a standalone lineage and print its tip; `-b` points a branch at it, `--rejoin` merges it back so a later split resumes from there.
- `version subtree push --prefix=<dir> <repository> [+][<local-rev>:]<remote-ref>` — split, then push the resulting tip to `<remote-ref>` on `<repository>`.
- `version verify-pack [-v|--verbose] <pack.idx>...` — verify a pack and, with `-v`, list its objects (`<sha> <type> <size> <size-in-pack> <offset>`; delta entries add their chain depth and base object id) followed by the `non delta:`/`chain length = N:` summary and `<pack>: ok`.
- `version checkout-index [-a|--all] [-f|--force] [-q|--quiet] [--prefix=<prefix>] [--] [FILE...]` — write files from the index into the working tree (executable bit included). An existing file is left alone unless `-f`.
- `version patch-id [--stable|--verbatim]` — read a patch on standard input and print `<patch-id> <commit-id>` for each patch in it. The id hashes the diff with all whitespace removed and the hunk headers dropped, so it is unchanged by a shift in line numbers; multi-patch input (`log -p`) yields one line per commit. Byte-identical to `git patch-id`.
- `version rerere [status|remaining|diff|forget <pathspec>|clear|gc]` — reuse recorded conflict resolutions (git's rerere). `status` lists paths with a recorded preimage, `remaining` lists paths still conflicted, `diff` shows a unified diff of the recorded preimage against the file as it stands now, `clear` drops the session's unresolved preimages and MERGE_RR, `forget <pathspec>` resets a path's recorded resolution, `gc` prunes old entries. The rr-cache uses git's conflict-content hash and normalized preimage format.
- `version read-tree TREE-ISH` — replace the index with the contents of a tree.
- `version commit-tree TREE [-p PARENT]... -m MESSAGE` — create a commit object.
- `version update-ref REF NEWVALUE [OLDVALUE]` / `version update-ref -d REF [OLDVALUE]` — set or delete a ref (with optional compare-and-swap old value).
- `version symbolic-ref HEAD [REF]` — print the branch HEAD points at, or (with REF) point HEAD at REF without touching the working tree.
- `version show-ref` — list `<oid> <refname>` for branches and tags.
- `version for-each-ref [PATTERN]` — list `<oid> <objecttype>\t<refname>` for branches and tags, optionally filtered by a refname prefix.
- `version rev-list [--count] [--all|--branches|--tags] [--max-count=<n>|-n <n>|-<n>] [--skip=<n>] [--reverse] [--merges|--no-merges] [--min-parents=<n>] [--max-parents=<n>] [--first-parent] [--parents] [--oneline] [--objects] [--topo-order|--date-order] <REV>... [--] [PATH...]` — list (or count) commits reachable from the given revisions. Revisions may be ranges (`A..B`, `A...B`) or exclusions (`^X`). Output is newest-first in committer-date order, git's default; `--topo-order` keeps a line of development contiguous instead. `--objects` also lists the trees and blobs the commits reach, each with the path it appears under (empty for a root tree). Paths after `--` limit the walk with git's default history simplification.

## Running from a subdirectory

Path arguments are resolved against the directory the command runs in, not the worktree root, as git does. `version add nested.txt` inside `sub/` stages `sub/nested.txt`; `..` reaches above the current directory, and `:(top)path` or `:/path` anchors a pathspec at the root instead. A pathspec that climbs above the worktree root is refused with exit 128.

Where paths are *printed*, the split follows git's:

| worktree-relative | relative to the current directory |
|---|---|
| `status --porcelain` | `status` (long) |
| `diff --name-only`, `--name-status`, `--stat` | `status --short` |
| patch headers (`a/sub/nested.txt`) | `ls-files`, `ls-tree`, `grep`, `clean` |

`--porcelain` is the scriptable contract and stays worktree-relative on purpose; `--short` shows the same records to a human and relativises them. `ls-files`, `ls-tree`, `grep` and `clean` also limit themselves to the current directory's subtree, as git does.

For `diff`, `grep` and the history commands, an operand that names neither a revision nor an existing path is git's `fatal: ambiguous argument` with exit 128, rather than being silently treated as matching nothing.

Commands not listed above have not been checked from a subdirectory and may still assume the worktree root.

## git command names

`version` names four commands differently from git. Git's spelling is accepted for each and dispatches to ours:

| git | `version` |
|---|---|
| `add` | `stage` |
| `commit` | `save` |
| `rm` | `remove` |
| `fsck` | `verify` |

These are convenience aliases for the command *name* only. The aliased commands keep this CLI's flags and output, which differ from git's: `stage` and `remove` report what they did where git is silent, `verify` prints an object count, and git-only flags such as `add -A`/`-u`/`-n`, `rm -r`/`--cached`/`-n`, and `commit -a`/`--allow-empty` are not accepted. Do not read `version add` as `git add`.

## History

### log

Syntax: `version log [--oneline] [--stat] [-p|--patch] [-U<n>|--unified=<n>] [--show-signature] [--format=<fmt>] [-<n>|-n <count>|--max-count=<n>] [--skip=<n>] [--reverse] [--merges|--no-merges] [--first-parent] [--topo-order|--date-order] [<REV>...] [--] [PATH...]`.

Purpose: show commit history from HEAD or a revision. Author dates render in git's default format (`Www Mmm D HH:MM:SS YYYY ±HHMM`, in the commit's timezone). `--oneline` prints one compact `<short-id> <subject>` line per commit (short id abbreviated to git's shortest-unique length, 7-char floor). `-<n>`, `-n <count>`, or `--max-count=<n>` limits the number of commits shown. Revision selection is the same as `rev-list`'s and shares its implementation: several revisions list their union, ranges (`A..B`, `A...B`) and exclusions (`^X`) work, `--skip`, `--reverse`, `--merges`/`--no-merges`, `--first-parent` and `--topo-order` apply, and paths after `--` limit the history with git's default simplification. The walk follows every parent by default, not only the first.

### show

Syntax: `version show [--stat] [REV | REV:PATH]`.

`REV:PATH` prints the object at that path: a blob's contents verbatim, or git's `tree <spec>` listing for a directory.

Purpose: show one commit and its changes (a minimal git-format unified diff). `--stat` replaces the patch with git's per-file change-bar summary.

Both fail on unknown revisions, missing commit objects, or malformed trees.

## Branches, tags, replay, and stash

### branch

Syntax: `version branch list`, `list --verbose`, `list --contains REV`, `list --merged [BRANCH]`, `list --no-merged [BRANCH]`, `current`, `exists NAME`, `resolve NAME`, `upstream [BRANCH]`, `contains REV`, `merged [BRANCH]`, `unmerged [BRANCH]`, `create NAME`, `switch NAME`, `rename OLD NEW`, `rename NEW`, `delete [--force] NAME`, `integrate NAME`, `integrate --finalize`, `integrate --abort`, `finalize`, `set-upstream BRANCH REMOTE REMOTE_BRANCH`, `unset-upstream BRANCH`, `ahead-behind BRANCH`, `update NAME`.

Purpose: inspect and manage branch lifecycle, tracking, and integration. `version branch list --verbose` prints sorted branches with current marker, short tip id, and commit subject. `version branch list --contains REV` is a Git-compatible alias for `version branch contains REV`. `version branch list --merged [BRANCH]` and `version branch list --no-merged [BRANCH]` are Git-compatible aliases for `version branch merged [BRANCH]` and `version branch unmerged [BRANCH]`. `version branch current` prints only the attached branch name and fails on detached HEAD. `version branch exists NAME` is quiet and reports branch existence by exit status. `version branch resolve NAME` prints only the branch tip object id plus a trailing newline. `version branch upstream [BRANCH]` prints the configured upstream as `remote/branch`, defaulting to the current branch when BRANCH is omitted. `version branch contains REV` resolves REV as a commit and prints the sorted branch names whose tips contain that commit. `version branch merged [BRANCH]` prints sorted branch names whose tips are ancestors of the current branch, or of BRANCH when provided. `version branch unmerged [BRANCH]` prints sorted branch names whose tips are not ancestors of the current branch, or of BRANCH when provided.

Common failures: invalid ref name, branch exists/missing, dirty switch target, branch checked out in another worktree, no upstream configured, active integration conflict.

### merge

Syntax: `version merge [OPTIONS] [TARGET...]`, `version merge --continue [--verify|--no-verify]`, `version merge --abort`, `version merge --quit`.

Purpose: merge one or more TARGET revisions into the current branch using the three-way merge engine and persistent conflict state. The content merge is a hunk-level three-way text merge matching git's `ll_merge` (a port of xdiff's `xdl_merge`, over a port of git's own diff, including `xdl_change_compact` group sliding and conflict refinement). Like git's merge machinery it diffs with the **histogram** algorithm by default (`git merge-file` is the one that defaults to Myers), and `-Xdiff-algorithm=` selects another. The merge behaves as follows: cleanly-merged hunks stay outside the conflict markers, two changes merge independently when at least one common line separates them (changes on adjacent lines conflict, exactly as git does), add/add paths are merged against an empty base, and conflicts fewer than three common lines apart combine into a single hunk, while preserving one-sided regular-file mode changes, materializes clean symlink additions by attempting host symlink creation when enabled or writing plain link-target files when `core.symlinks=false`, the default engine and selected diff-algorithm modes including explicit Myers add script-based multi-hunk line matching and identical-content/mode-only auto-resolution, synthesizes clean recursive virtual bases for criss-cross histories in the default/recursive engine and rejects multiple merge bases for `-s resolve`, supports similarity-based rename detection with configurable rename limits, opt-in copy-base detection for add/add paths including `find-copies-harder` aliases, and configurable directory-rename application or conflict behavior for additions under a renamed directory including ambiguous split-directory conflicts, same-destination rename/rename including regular-file mode-only changes and rename/add collision staging, records basic side-order-independent rerere preimage/postimage metadata with exact preimage scanning, `rerere.autoupdate` enablement, and replay reuse for rebase/cherry-pick/revert conflicts, and recognizes built-in `merge=ours`, `merge=theirs`, `merge=union`, binary/text merge attributes, and configured external `merge.<name>.driver` commands for blob conflicts from root and nested `.gitattributes` plus `.git/info/attributes`, including `%O`/`%A`/`%B`/`%L`/`%P` and `%S`/`%X`/`%Y` label placeholders with `GIT_DIR`, `GIT_COMMON_DIR`, `GIT_WORK_TREE`, and `GIT_INDEX_FILE` set, with `merge=text` or `!merge` resetting earlier driver rules and `merge.<name>.recursive` honoring built-in `ours`, `theirs`, and `union` or delegating to another configured driver command for virtual-base merges. TARGET may be omitted to merge the configured upstream when `merge.defaultToUpstream` is not false, or may name a branch, tag, remote-tracking ref, full or abbreviated commit id, or supported revision suffix. Supported options include `--ff`, `--ff-only`, `--no-ff`, `--no-commit`, `--squash`, `-m/--message`, `-F/--file`, `--edit`, `--no-edit`, `--log[=<n>]`, `--signoff`, `--cleanup=MODE`, `--stat`, `--no-stat`, `--summary`, `--compact-summary`, `--quiet`, `--verbose`, `--progress`, `--no-progress`, `--autostash`, `--no-autostash`, `-s/--strategy`, `-X ours|theirs|ignore-space-change|ignore-all-space|ignore-space-at-eol|ignore-cr-at-eol|renormalize|no-renormalize|find-renames[=<n>]|renames=<n>|rename-limit=<n>|find-copies[=<n>]|find-copies-harder|copies=<n>|no-copies|no-renames|directory-renames[=true|false|conflict]|no-directory-renames|diff-algorithm=patience|histogram|minimal|myers|subtree[=<path>]|recurse-submodules|no-recurse-submodules`, `--conflict=merge|diff3|zdiff3`, `--marker-size N`, `--renormalize`, `--no-renormalize`, `--find-renames[=<n>]`, `--find-copies[=<n>]`, `--find-copies-harder`, `--rerere-autoupdate`, `--verify`, `--no-verify`, `--verify-signatures`, `--no-verify-signatures`, `--gpg-sign`, `--no-gpg-sign`, `--recurse-submodules`, `--no-recurse-submodules`, and `--allow-unrelated-histories`; `merge.ff`, `merge.autostash`, `merge.autoEdit`, `merge.log`, `merge.stat`/`merge.summary`, `merge.renormalize`, `merge.renames`, `merge.renameLimit`, `merge.directoryRenames`, `branch.<name>.mergeOptions`, `merge.verifySignatures`, `submodule.recurse`, `merge.recurseSubmodules`, `commit.gpgSign`, and `user.signingKey` supply defaults when no explicit option overrides them. `-s resolve` uses the native engine with rename detection disabled, `-s subtree` enables subtree rewriting, `-s octopus` is accepted for multi-target merges but rejected for single-target merges, and explicit two-head strategies are rejected for multi-target merges. `--verify-signatures` verifies target commits through local `git verify-commit`/GPG tooling before mutation; `--gpg-sign[=<key>]` signs created merge commits through local `gpg`, preserving signing intent across `merge --continue` via `MERGE_MODE`. `-Xsubtree=<path>` rewrites the target and merge-base trees below the requested prefix before the three-way merge; bare `-Xsubtree` attempts conservative prefix inference and rejects ambiguous or missing inference. Clean divergent single-target merges create a two-parent merge commit unless `--no-commit` or `--squash` is selected, running `pre-merge-commit` before automatic merge commit creation when hooks are enabled. Clean multi-target merges create a conservative octopus commit; clean multi-target `--squash` writes squash state without advancing `HEAD`, and clean multi-target `--no-commit` writes a multi-line `MERGE_HEAD` plus index state without advancing `HEAD` so `merge --continue` can create the octopus commit. `--autostash` records temporary stash commits in `MERGE_AUTOSTASH`, applies them after successful committed/fast-forward/squash/no-commit merges and abort/continue flows, and stores them on the normal stash stack for quit or when autostash application itself cannot be completed cleanly. Conflicts leave working-tree conflict markers, stage 1/2/3 index entries for unmerged paths, Version merge state, and Git-compatible `MERGE_HEAD`/`MERGE_MSG`/`MERGE_MODE`/`AUTO_MERGE` state for `version merge --continue`, `--abort`, or `--quit`. Conflict markers carry git's labels: `HEAD` for the current side, the target's name for the other, and the abbreviated merge-base id for the base section under `--conflict=diff3`/`zdiff3`; they follow the file's line-ending style, so a CRLF file gets CRLF-terminated markers. `-Xours`/`-Xtheirs` resolve only the conflicting hunks, keeping the other side's cleanly-merged changes (the `merge=ours` attribute, by contrast, keeps our file whole, as in git), and `merge=union` unions each conflicting hunk. A rename makes each marker name that side's own path (`<<<<<<< HEAD:old.txt` / `>>>>>>> feature:new.txt`); renames to the same path keep the plain labels. The `-Xignore-space-change`/`-Xignore-all-space`/`-Xignore-space-at-eol`/`-Xignore-cr-at-eol` options fold whitespace inside the diff, so a side whose only change is ignorable whitespace counts as unchanged and the other side's file is taken verbatim; lines keep their original whitespace when written out. `version merge --continue` and `version merge --abort` can also consume Git-created conflicted merge state when `MERGE_HEAD`/`ORIG_HEAD` and unmerged index stages are present.

Common failures: detached HEAD, dirty tree, unknown target revision, no merge base without `--allow-unrelated-histories`, active merge/replay state, unresolved conflicts, unsupported strategy or strategy option.

### tag

Syntax: `version tag [-a|-s|-u KEY] [-f] [-m MSG] NAME [REV]`, `version tag -d NAME...`, `version tag -v NAME...`, `version tag [-n[NUM]] [-l] [PATTERN...]`, `version tag --contains REV`, `version tag --merged REV`, `version tag --points-at REV`, `version tag --sort=KEY`, `version tag create NAME`, `version tag create NAME REV`, `version tag create -a NAME -m MESSAGE`, `version tag create -a NAME REV -m MESSAGE`, `version tag delete NAME`, `version tag remove NAME`, `version tag list`, `version tag rename OLD NEW`, `version tag list --points-at REV`, `version tag list --contains REV`, `version tag exists NAME`, `version tag resolve NAME`, `version tag peel NAME`, `version tag show NAME`.

Purpose: manage lightweight and annotated tags. `version tag create NAME` creates a lightweight tag at `HEAD`; `version tag create NAME REV` creates a lightweight tag at a resolved revision. `version tag create -a NAME -m MESSAGE` creates an annotated tag object at `HEAD`; `version tag create -a NAME REV -m MESSAGE` creates an annotated tag object at a resolved revision. `version tag list --points-at REV` is read-only and prints tag names whose peeled target is the resolved revision. `version tag list --contains REV` is read-only and prints tag names whose peeled commit contains the resolved commit revision. `version tag exists NAME` is read-only, prints nothing, and reports tag existence by exit status. `version tag resolve NAME` is read-only and prints only the object id stored in the tag ref, followed by a newline. `version tag peel NAME` is read-only and prints the peeled target id, following annotated tag chains. `version tag show NAME` is read-only and prints stable tag details; annotated tags include the tag object id, peeled target id, target type, and message. `version tag rename OLD NEW` moves a tag ref without rewriting the target object. `version tag delete NAME` and `version tag remove NAME` report the deleted tag and its abbreviated old target, in git's wording. git's own grammar is accepted alongside these spellings: `version tag NAME [REV]` creates, `-a`/`-s`/`-u KEY` annotate or sign, `-m MSG` supplies the message and implies `-a`, `-f` moves an existing tag, `-d` deletes, and `-v` verifies. List filters (`-l PATTERN`, `--contains`, `--merged`, `--points-at`, `--sort`, `-n[NUM]`) combine in one parse, matching git. `-n[NUM]` aligns the tag name in 15 columns and follows it with the first `NUM` lines of its message; creating is silent, and `-f` prints `Updated tag` only when the ref actually moves.

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

Syntax: `version fetch REMOTE`, `version fetch --depth N REMOTE`, `version fetch --deepen N REMOTE`, `version fetch --unshallow REMOTE`, `version fetch REMOTE REF`.

Purpose: fetch objects and refs from a remote. With an explicit `REF`, only that ref is fetched: `.git/FETCH_HEAD` is recorded and git's ` * branch REF -> FETCH_HEAD` summary is printed (plus the opportunistic remote-tracking update line), without the full tag advertisement version prints for a bare `fetch REMOTE`. On a shallow repository, `--deepen N` extends the shallow boundary by `N` commits (requesting the `deepen-relative` capability and echoing the current boundary), and `--unshallow` fetches the complete history and removes `.git/shallow` (it fails on a repository that is not shallow); `--depth`, `--deepen`, and `--unshallow` are mutually exclusive and require a smart (HTTP/SSH) transport.

Common failures: missing remote, unsupported transport, protocol/pack failure, unsupported shallow request.

### push

Syntax: `version push REMOTE`, `version push REMOTE BRANCH`, `version push --no-verify REMOTE BRANCH`, `version push --force REMOTE BRANCH`, `version push --delete REMOTE REF`, `version push REMOTE SRC:DST`, `version push REMOTE +SRC:DST`, `version push REMOTE :DST`, `version push --tags REMOTE`, `version push REMOTE --tags`, `version push --no-verify --tags [REMOTE]`.

Purpose: push or delete refs on a remote. Branch and tag push both support local, `file://`, HTTP(S), and SSH remotes. By default a branch update must fast-forward the remote; `--force` (or `-f`) permits a non-fast-forward update. Tag push refuses to overwrite a differing existing remote tag unless `--force` is also given (`push --tags --force`). `--delete` (or `-d`) removes a remote ref (`REF` is a branch name, or a full `refs/...` ref such as `refs/tags/v1`); it cannot be combined with `--tags` or `--force`. A refspec `SRC:DST` pushes the commit named by `SRC` to remote ref `DST` (a branch name or full `refs/...` ref); a leading `+` forces a non-fast-forward update, and an empty `SRC` (`:DST`) deletes `DST`. With no refspec (`push REMOTE`), the configured `remote.<REMOTE>.push` refspec(s) are applied (each parsed like a command-line refspec); it errors if none are configured.

Common failures: missing remote, no refspec given and `remote.<name>.push` not configured, rejected update, remote branch or tag changed during push, non-fast-forward without `--force`, refusing to overwrite a differing remote tag, deleting a ref that does not exist on the remote, unsupported transport, pre-push hook failure.

### lfs

Syntax: `version lfs track [PATTERN...]`, `version lfs untrack PATTERN...`, `version lfs ls-files [-l] [REF]`, `version lfs status`, `version lfs pointer --file=PATH`, `version lfs env`, `version lfs fetch [--all] [REMOTE [REF...]]`, `version lfs pull [REMOTE]`, `version lfs checkout [PATH...]`, `version lfs push REMOTE [REF]`, `version lfs fsck`, `version lfs prune [--dry-run]`, `version lfs migrate import --include=PATTERN`, `version lfs migrate export --include=PATTERN`, `version lfs migrate info [--everything]`, `version lfs lock PATH`, `version lfs unlock PATH`, `version lfs unlock --id ID`, `version lfs unlock PATH --force`, `version lfs locks`, `version lfs locks --path PATH`, `version lfs locks --id ID`, `version lfs locks --verify`.

Purpose: manage Git LFS. `track` with no arguments lists the `filter=lfs` patterns (`Listing tracked patterns` / `Listing excluded patterns`); with arguments it appends `PATTERN filter=lfs diff=lfs merge=lfs -text` to `.gitattributes` and prints `Tracking "PATTERN"` (or `"PATTERN" already supported`). `untrack` removes those rules. `ls-files` lists the LFS-pointer files in the index (or `REF`'s tree) as `<oid> <*|-> <path>` — `*` when the media is cached locally, `-` when only the pointer is present; `-l`/`--long` prints the full 64-hex oid. `status` prints the staged (`Objects to be committed:`) and unstaged (`Objects not staged for commit:`) sections, tagging each path `(LFS: <short-oid>)` or `(Git: <short-oid>)`. `pointer --file=PATH` prints the LFS pointer for a file (the `Git LFS pointer for PATH` banner goes to stderr, the pointer body to stdout). `env` prints the working/git/media directories and the LFS endpoint. `fetch` downloads the media referenced by a commit (default HEAD, or every branch/tag tip with `--all`) into the local cache and reports `fetch: N object(s) found, done.`; `pull` fetches then materializes the working tree; `checkout` materializes cached media into the working tree (optionally limited to PATHs); `push` uploads a commit's referenced media to REMOTE. `fsck` verifies that each cached object's sha256 matches its oid (`Git LFS fsck OK`, or `corruptObject: PATH (OID) is corrupt` and a non-zero exit). `prune` deletes cached objects not referenced by any branch/tag tip or the index (`prune: N local object(s), M retained, done.`; `--dry-run` reports without deleting). `migrate import --include=PATTERN` rewrites history so matching blobs become LFS pointers (caching the media and adding the `.gitattributes` rule), `migrate export --include=PATTERN` reverses it, and `migrate info` summarizes blob count and byte size per file extension (`--everything` covers all branches; otherwise the current branch). Migrate preserves author and committer identities and timestamps, and updates the affected refs, index, and working-tree `.gitattributes`.

Common failures: not in a repository, unknown subcommand or option, no such file for `pointer`/`checkout`, unresolvable `REF`, no LFS server configured for `fetch`/`pull`/`push`, unreachable media object, `migrate` on a detached HEAD, `migrate export` of an object whose media is not cached.

### lfs locks

Purpose: manage Git LFS file locks on the configured LFS server (`lfs.url`, else `remote.origin.url`). `lock` creates a lock for `PATH` and prints `Locked PATH`; `unlock` releases a lock by `PATH` (resolved to its id) or by `--id ID` and prints `Unlocked ...`; `--force` releases a lock held by another user. `locks` lists active locks as `PATH<TAB>OWNER<TAB>ID:<id>`; `--verify` prefixes each line with `O ` (owned by you) or `T ` (held by others). Locking speaks git-lfs's HTTP lock API (`POST /locks`, `GET /locks`, `POST /locks/verify`, `POST /locks/<id>/unlock`) with credential-helper/URL-userinfo authentication; SSH remotes use the pure-SSH `git-lfs-transfer` `lock`/`list-lock`/`unlock` verbs, falling back to `git-lfs-authenticate` + the HTTP API.

Common failures: no LFS server configured, path already locked by another user (lock conflict), lock not found for the given path or id, releasing another user's lock without `--force`, unsupported transport (locking needs an HTTP or SSH remote), authentication failure.

## Sparse, worktree, and submodule

### sparse / sparse-checkout

Syntax: `version sparse-checkout set [--cone|--no-cone] DIR...`, `version sparse-checkout add [--cone|--no-cone] DIR...`, `version sparse-checkout list`, `version sparse-checkout status`, `version sparse-checkout reapply`, `version sparse-checkout init [--cone|--no-cone]`, `version sparse-checkout disable`. `version sparse` is accepted as an alias for git's `sparse-checkout`.

Purpose: keep only selected tracked paths materialized in the working tree, matching git's `sparse-checkout`. `set`/`add` default to **cone mode** (arguments are directories): they write git's cone patterns (`/*`, `!/*/`, `/dir/`, plus `!/dir/*/` ancestor entries for nested directories) to `.git/info/sparse-checkout`, set `core.sparseCheckout` and `core.sparseCheckoutCone`, materialize the working tree, and set git skip-worktree bits on the excluded index entries (writing a version-3 index) so `git status`/`ls-files -t` round-trip correctly. `--no-cone` writes raw gitignore-style patterns instead. `list` prints the recursive directory names (cone) or the raw patterns; it fails with `this worktree is not sparse` when disabled. `reapply` re-materializes from the current patterns. `disable` clears the config flag and restores the full working tree while keeping the pattern file (git parity).

Common failures: dirty tree, unborn branch, unsafe deletion/materialization target, `this worktree is not sparse`.

### worktree

Syntax: `version worktree add PATH BRANCH`, `version worktree add --detach PATH REV`, `version worktree list`, `version worktree current`, `version worktree remove PATH`.

Purpose: manage linked worktrees with shared objects/refs and isolated HEAD/index/sparse/replay state.

`version worktree list` prints one stable line per known worktree using marker brackets: `[current primary]` for the current primary worktree, `[linked branch-in-use]` for a linked branch worktree, `[linked detached]` for detached linked worktrees, and `[linked missing branch-in-use]` when linked metadata remains but the worktree path is missing. Branch lines end with `branch NAME`; detached lines end with `detached SHORTOID`. `version worktree current` prints the same stable single-line shape for only the current worktree, using `[current primary]` or `[current linked]` to distinguish the current repository layout.

Common failures: branch already checked out elsewhere, target exists, dirty removal target, invalid common-dir or backlink metadata.

### submodule

Syntax: `version submodule init`, `version submodule update [--recursive]`, `version submodule status`, `version submodule foreach [--recursive] COMMAND`, `version submodule sync [--recursive]`, `version submodule deinit [--force] [--all|PATH...]`.

Purpose: initialize, update, inspect, and manage supported Git-compatible submodules.

`version submodule status` prints one stable line per active submodule. The leading marker matches the Git-style status class and is followed by an explicit label: ` ` means clean, `-` means missing or not checked out, `+` means the submodule HEAD is at a different commit than the gitlink, and `!` means the submodule worktree is dirty. Sparse-excluded submodule paths are omitted from this report.

`version submodule foreach COMMAND` runs a shell command in each populated submodule (path-sorted), printing `Entering '<path>'` and exposing `$name`, `$sm_path`, `$displaypath`, `$sha1`, and `$toplevel` to the command; it stops if a command exits non-zero. `version submodule sync` copies each submodule's `.gitmodules` URL into the superproject's `.git/config` (`submodule.<name>.url`) and into the submodule's own `remote.origin.url`, printing `Synchronizing submodule url for '<path>'`. `version submodule deinit PATH...` (or `--all`) empties the named submodules' working trees and removes their `submodule.<name>.*` config while keeping the `.gitmodules` entry, printing `Cleared directory '<path>'` and `Submodule '<name>' (<url>) unregistered for path '<path>'`; `--force` is required to discard local modifications, and `--all` is required to deinitialize every submodule.

Common failures: malformed `.gitmodules`, unsafe path, relative URL without a configured superproject remote, unsupported resolved URL, missing gitlink object, checkout preflight failure.

## Archive export

### archive

Syntax: `version archive REV`, `version archive REV --output PATH`, `version archive REV --format tar|zip`, `version archive REV [--] PATHSPEC...`.

Purpose: export the tree referenced by `REV` directly from repository objects without reading the working tree, index, sparse checkout materialization, or linked-worktree state.

Default output is `archive.tar`. `--format zip` defaults to `archive.zip`; format names are accepted case-insensitively. The format is inferred from the `--output` suffix when `--format` is omitted (`.zip`→zip, `.tar.gz`/`.tgz`→tar.gz, `.tar.xz`/`.txz`→tar.xz, `.tar.bz2`/`.tbz2`/`.tbz`→tar.bz2). Proprietary container suffixes `.zipx`, `.7z`, and `.rar` are rejected. Unknown `--long-option` values are rejected before `--`; pathspecs that intentionally start with `--` must follow the `--` separator.

Built-in formats are `tar`, `tar.gz` (`tgz`), and `zip` — `tar.gz` uses the integrated Ada Zlib gzip path and ZIP entries use its stored-deflate path. Any other format (e.g. `tar.xz`, `tar.bz2`, or a custom name) is produced through git's tar-filter mechanism: the built tar is piped through the shell command configured in `tar.<format>.command` (for example `tar.tar.xz.command = "xz -c"`). A format with no built-in support and no configured filter is rejected with `Unknown archive format`, matching git.

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
