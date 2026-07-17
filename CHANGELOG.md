- Fix: `mktag` now runs git's strict fsck before writing and rejects a malformed tag object with git's exact `error: tag input does not pass fsck: <id>: <detail>` + `fatal: ... strict fsck check` (exit 128): a tagger line missing the `<email>` (`missingEmail`), with a bad (`badTimezone`) or omitted (`badDate`) timezone, an invalid `tag` name (`badTagName`), or any header after `tagger` (`extraHeaderEntry`). Previously all of these were accepted and written as a real tag object.
- Fix: `describe` no longer aborts (`rebase of merge commits not supported`) on any repository containing a merge commit -- the tag-distance count now does a full all-parents walk of `<tag>..<commit>` (git's definition) instead of reusing the linear rebase replay, so `describe` works and matches git across merge histories.
- Fix: `init --bare` no longer writes a spurious `core.logallrefupdates = true` into the config; git omits it for bare repositories (the reflog default is off there).
- Fix: `notes add` writes git's exact notes-commit message `Notes added by 'git notes add'` (was `'version notes add'`), so the `refs/notes/commits` object id matches git.
- Fix: `config unset` of a key that does not exist now exits 5 with no diagnostic, as git does, instead of printing an error and exiting 1.
- Fix: the recursive merge backends (`merge-recursive`, `merge-recursive-ours`/`-theirs`, `merge-subtree`) now synthesize a virtual ancestor from several merge bases -- folding them pairwise into `virtual merge base` commits as git does -- instead of using only the first base. On a criss-cross (two-merge-base) history this fixes a wrong stage-1 blob on conflicts and a silently-wrong clean merge that discarded a committed change; the conflicted index now byte-matches git.
- Fix: `merge-resolve` now refuses (`Error: Your local changes to the following files would be overwritten by merge`, the paths, exit 2) when the index carries staged changes not in HEAD, leaving them intact, instead of merging over them and silently discarding the staged change.
- Fix: `fast-import` now inherits the destination ref's current tip as the implicit parent (and base tree) when a `commit` command omits `from`, instead of clearing state to produce a parentless commit whose tree holds only its own changes -- a second commit on a branch previously dropped every earlier file and orphaned history.
- Fix: `fast-export --all` now emits lightweight tags (as `reset refs/tags/<name>` + `from`) instead of dropping them; annotated tags are deferred to the end as git does, and refs are walked in sorted order so multi-branch output matches git.
- Fix: `fast-export <ref>` with a short name now canonicalizes it to its full `refs/heads|tags/*` form (git's rev-parse DWIM order), so the `reset`/`commit` lines recreate the ref on reimport instead of emitting the bare argument (which created no ref).
- Fix: `merge-file` now refuses to merge binary content (`error: Cannot merge binary files: <path>`, exit 255, current file untouched) using git's NUL-in-first-8000-bytes heuristic, instead of 3-way merging it as text and corrupting the file.
- Fix: `index-pack --keep[=<reason>]` now writes the `pack-<sha>.keep` file (empty, or the reason as its contents) that marks the pack exempt from gc/repack, instead of accepting the flag as a no-op.
- Fix: `mktree` now rejects malformed input as git does instead of silently dropping it: a non-empty line it cannot parse aborts the command (`fatal: input format error: <line>`, exit 128, no tree written), a declared type that disagrees with the mode fails (`entry '<p>' object type (<t>) doesn't match mode type (<m>)`), and (without `--missing`) an entry whose object's real type differs from the declared type fails (`entry '<p>' object <oid> is a <actual> but specified type was (<t>)`). Previously such input produced a corrupt or truncated tree.
- Fix: `config set` now quotes and escapes values git's way -- a value with leading/trailing whitespace or a `#`/`;` comment introducer is wrapped in double quotes, and `\`, `"`, tab and newline are escaped. Previously such a value was written raw, so a later read (by git or version) silently truncated or mangled it. The reader now also preserves quote-protected whitespace across a round-trip.
- Fix: `config unset` on a key with multiple values now refuses (`warning: <key> has multiple values`, exit 5) and leaves the file untouched, as git does, instead of silently deleting every value and exiting 0.
- Fix: `commit-tree` now joins repeated `-m` options as separate paragraphs (blank line between) like git, instead of keeping only the last message and dropping the rest.
- Fix: `checkout <branch>` now attaches HEAD to the branch (`ref: refs/heads/<name>`) as git does, printing `Switched to branch '<name>'` (or `Already on '<name>'`), instead of always detaching HEAD at the raw commit -- every commit made after a `checkout <branch>` was silently orphaned. Checking out a commit, tag or other non-branch revision still detaches, and the HEAD reflog now matches git's `checkout: moving from <old> to <new>` form.
- Fix: `fast-import` now supports `M <mode> inline <path>` (the file's content carried in the stream as the following data block) -- version read the literal `inline` as an object id and failed the whole import with `invalid object id hex digit`.
- Fix: `fast-import` now reads an `M` line's short octal modes as git does -- `644`/`755` mean regular files (`100644`/`100755`), where version recorded them as gitlinks (`160000`), silently importing every file of such a stream as a broken submodule. A mode outside the set git accepts is now refused (`corrupt mode: <line>`) instead of becoming a gitlink.
- Fix: `fast-import` now defaults a commit's author to its committer when the stream omits the `author` line (git parity), instead of writing a literal empty `author ` line -- a corrupt commit with a wrong object id.
- Fix: `notes add` no longer silently overwrites an existing note -- git refuses (`Cannot add notes. Found existing notes for object <id>. Use '-f' to overwrite existing notes`, exit 1) unless `-f`/`--force` is given, and reports `Overwriting existing notes for object <id>` when it is. Both are now matched, and `-f`/`--force` is accepted.
- Fix: `archive` now streams the archive to standard output when no `--output`/`-o` is given (git parity), instead of writing an `archive.tar` file into the working directory. The tar itself is now byte-identical to git: entries in recursive tree order (not all directories first), git's `tar.umask` modes (0664/0775, symlinks 0777), the commit's committer time as mtime, `root`/`root` owner, devmajor/devminor and checksum fields formatted as git does, and the archive padded to git's 20-block (10240-byte) record. Multi-level `--prefix` matches too (the prefix is one directory entry, not decomposed).
- Fix: `clean -fd` no longer deletes a nested git repository (a directory holding a `.git`) -- git preserves it and requires a doubled force (`-ff`), which version now honours (the `-f` count is threaded into `Version.Clean`). Previously `clean -fd` removed an embedded repo outright, silent data loss.
- Fix: `apply --index` now enforces git's precondition that each patched file already matches the index -- on a dirty working tree it refuses (`<path>: does not match index`, exit 1) and changes nothing, instead of silently applying to the working tree and staging the result. `--cached` (index only) stays exempt, and new-file creation is unaffected.
- Fix: `log` now walks the full commit history in commit-date order across ALL parents, not just the first-parent chain -- a merge previously hid every commit reachable only through its second-or-later parent from `log`/`--oneline`/`--stat`/`-p`/`--format`. Also adds the `Merge: <p1> <p2>` header line for merge commits and suppresses the per-merge diff under `--stat`/`-p` by default, both matching git.
- Git parity: new `version http-fetch [-a] [-v] [-w <name>] <commit> <url>` -- fetch over the dumb HTTP protocol (a server with no git on it). Identical to git against both a loose and a packed server; `-w` writes the id into `$GIT_DIR/refs/<name>`, as git's does.
- Scope: `http-push` (the dumb protocol's WebDAV write half) is out of scope, alongside the server-side tools its use would require.
- Scope: git's experimental commands (`replay`, `repo`, `backfill`, `last-modified` -- their man pages say "THIS COMMAND IS EXPERIMENTAL. THE BEHAVIOR MAY CHANGE.") are not parity targets. version implements `backfill`, `last-modified` and `repo info` anyway, but they are not held to byte-parity and do not count towards command coverage.
- New `version repo info [--all|-z|<key>...]` (byte-identical to git's: `layout.bare`, `layout.shallow`, `object.format`, `references.format`) and `version repo structure`, which prints git's References block. git's object-count/size/largest-object sections of that table are not implemented yet, so `repo` still counts as an open gap. (git calls this command experimental.)
- Git parity: new `version multi-pack-index write|verify` -- byte-identical to git's `multi-pack-index` (see the versionlib entry for the same-second-mtime boundary).
- Git parity: new `version commit-graph write|verify` -- the commit-graph file is byte-identical to git's and git's own verifier accepts it.
- Git parity: new `version backfill` -- download the blobs a partial clone (`--filter=blob:none`) left behind, so the repository is complete again. Verified: a clone holding 1 of 3 historical blobs ends up with all 3.
- Git parity: new `version filter-branch [-f] [--index-filter <cmd>] [--tree-filter <cmd>] [--msg-filter <cmd>] [--subdirectory-filter <dir>] [--prune-empty] [<rev>]` -- rewrite history commit by commit, preserving each commit's author and committer, keeping the old tip under `refs/original/`. Byte-identical to git (rewritten commit ids included). Filters run the way git runs them: in an empty temporary working tree with `GIT_DIR`/`GIT_WORK_TREE`/`GIT_INDEX_FILE` set, which is what lets `git rm --cached` inside an index filter work at all.
- Git parity: new `version last-modified [<rev>] [-- <path>...]` (the last commit that touched each entry of the tree, reported as the history walk resolves them, as git does), `version refs list|verify` (the ref store), and `version diff-pairs -z` (raw diff records on stdin, patches out).
- Git parity: new `version fetch-pack [--all] <repository> [<ref>...]` (fetch the objects those refs need, touching no local ref, and print `<oid> <ref>`) and `version send-pack [--force] <repository> <refspec>...` (push, reporting as push does). Both byte-identical to git.
- Git parity: new `version fast-export [--all] [<ref>...]` and `version fast-import` -- the fast-import stream, both directions. Round-trips are exact: `version fast-export | git fast-import` and `git fast-export | version fast-import` both rebuild history whose commit, tree and tag ids are byte-identical to the original (40/40 randomized histories with merges, tags, deletes and exec bits). The stream *text* matches git's for a single line of history; when several refs share commits, version attaches those commits to refs in its own order (git's fast-export has its own heuristic there), so the bytes can differ while the history the stream builds does not.
- Git parity: new `version mailsplit [-o<dir>]` (an mbox on stdin or in files, split into numbered messages, the count on stdout) and `version mailinfo <msg> <patch>` (a mail on stdin: authorship to stdout, commit message and patch to the two files). Both byte-identical to git.
- Git parity: new `version index-pack [--stdin] [-o <idx>] [<pack>]` (writes the `.idx` and prints the pack's checksum), `version unpack-objects [-n]` (a pack on stdin, exploded into loose objects), and `version pack-objects [--stdout] [<base>]` (object ids on stdin, a pack out). index-pack and unpack-objects are byte-identical to git; version's packs are undeltified, so `pack-objects` writes a valid pack that git reads and verifies but whose bytes -- and therefore whose name -- are its own.
- Git parity: new merge plumbing -- `version merge-index [-o] [-q] <program> (-a | <file>...)` and `version merge-one-file <orig> <our> <their> <path> <orig-mode> <our-mode> <their-mode>` (a native port of git's git-merge-one-file script: the delete/add/add-identically/content-merge cases, its messages, and its exit codes).
- Git parity: the merge-strategy backends `version merge-ours`, `merge-recursive`, `merge-recursive-ours`, `merge-recursive-theirs`, `merge-subtree`, `merge-resolve` and `merge-octopus` (`<base>... -- <head> <remote>...`), merging into the index and working tree without committing. Note `merge-recursive-ours`/`-theirs` do *not* favour a side -- that is git's behavior, verified; `-Xours` is what favours.
- Git parity: new `version merge-tree --write-tree [--name-only] [-z] [--merge-base=<commit>] <commit1> <commit2>` -- merge two commits with no worktree and no index, printing the merged tree's id (conflicted paths carry the marked-up blob, as git's does), then the stage 1/2/3 entries, then the merge messages; exit 1 on conflict. 180/180 on randomized merges vs git.
- Git parity: new `version show-index` (pack index on stdin -> `<offset> <sha> (<crc32>)`), `version unpack-file <blob>` (blob contents to a temporary file, whose name is printed), and `version prune-packed [-n] [-q]` (drop the loose objects a pack already holds).
- Git parity: new `version ls-remote [--heads] [--tags] [--exit-code] [<repository>] [<pattern>...]`, `version check-attr [-a] <attr>... <path>...`, `version check-mailmap <contact>...`, and `version for-each-repo --config=<key> <command>...`. All byte-identical to git (check-attr verified over 120 randomized `.gitattributes` stacks, including macros, `!attr`, and cross-directory precedence).
- Git parity: new `version subtree add|merge|pull|split|push --prefix=<dir>` (with `--squash`, `--rejoin`, `--ignore-joins`, `--onto=`, `-b`, `-m`, `-q`) -- vendor a foreign history into a subdirectory and lift it back out. Commit ids, trailers, and output match `git subtree`; failures print `fatal:` and exit 128 as git's do.
- Git parity: commits, tags, and merges honour `GIT_AUTHOR_*`/`GIT_COMMITTER_*` and record the local timezone, so a commit made with the same content and identity gets git's object id.
- Git parity: a merge with no `-m` writes git's message (`Merge branch 'x'` / `Merge tag 'v1'` / `Merge commit '<rev>'`).
- Fix: `remote remove` now deletes the remote-tracking refs too.
- Fix: `blame` is now byte-identical to `git blame` (the diff it follows lines with needed git's indent heuristic). 450/450 on randomized histories.
- Git parity: new `version verify-pack [-v] <pack.idx>...` -- lists each packed object as `<sha> <type> <size> <size-in-pack> <offset>` (delta entries add the chain depth and their base's sha, and report the *delta's* size as git does), then the `non delta:` / `chain length = N:` summary and the `<pack>: ok` line.
- Git parity: new `version checkout-index [-a] [-f] [-q] [--prefix=<p>] [--] [FILE...]` -- write files from the index to the working tree, restoring the executable bit, leaving existing files alone (with git's `<path> already exists, no checkout` warning) unless `-f`.
- Git parity: `count-objects -v` prints git's verbose block (`count`/`size`/`in-pack`/`packs`/`size-pack`/`prune-packable`/`garbage`/`size-garbage`).
- Git parity: new `version difftool [--tool=<tool>] [--cached]` and `version mergetool [--tool=<tool>]` -- run the configured external tool (`diff.tool`/`merge.tool` + `difftool.<t>.cmd`/`mergetool.<t>.cmd`) once per changed or conflicted path, with git's `$LOCAL`/`$REMOTE`/`$BASE`/`$MERGED` in the environment. `mergetool` prints git's `Normal merge conflict for '<path>'` banner with the `{local}`/`{remote}` descriptions, keeps the conflicted file as `<path>.orig`, and stages the path when the tool exits 0. Both byte-identical to git for a scripted tool.
- Git parity: new `version bisect run <command> [<arg>...]` -- tests each bisected commit by running the command, taking its exit status as the verdict (0 good, 125 skip, 1..127 bad, 128+ aborts the run), and prints git's transcript (`running '<cmd>'`, each `Bisecting:` step, the first-bad commit with its `--stat`, then `bisect found first bad commit`). Byte-identical to `git bisect run`.
- Git parity: new `version patch-id [--stable|--verbatim]` -- reads a patch on stdin and prints `<patch-id> <commit-id>` per patch, hashing the diff with whitespace removed and the hunk headers dropped (so the id survives a change of line numbers), exactly as git does. Handles multi-patch input (`log -p`).
- Git parity: `cat-file <type> <object>` (the `blob`/`tree`/`commit`/`tag` form) is accepted alongside `-t`/`-s`/`-e`/`-p`, and errors when the object is not of the named type.
- Git parity: `ls-tree` accepts a pathspec (`ls-tree HEAD -- <path>`), and `name-rev` prefers a tag over a branch when both reach the commit at the same distance, as git does.
- Fix: `checkout`/`switch` no longer refuse merely because an untracked file exists; only a file the checkout would overwrite blocks it (git's rule).
- Git parity: `ls-files` implements `-o`/`--others`, `-m`/`--modified`, `-d`/`--deleted` and `--exclude-standard`, and rejects unknown options. It previously *ignored* flags it did not know, so `ls-files -o` silently listed the index (the tracked files) instead of the untracked ones -- the opposite of what was asked for.
- Git parity: `diff` (and `show`, `log -p`, `format-patch`) now produce git's hunks exactly -- the diff engine is git's own, indent heuristic included. `version diff` previously disagreed with `git diff` on ~12% of inputs; it is now byte-identical across randomized fuzzing, including indented source and `-U0`/`-U5`.
- Git parity: `diff` accepts `-U<n>`/`--unified=<n>`, and `log` accepts `-p`/`--patch` and `-U<n>` (previously rejected outright).
- Git parity: `show <rev>:<path>` prints the blob's contents (or git's `tree <spec>` listing for a directory) instead of failing with "object is not a commit".
- Git parity: `rev-parse` accepts `--show-toplevel`, `--git-dir` (reported relative when it sits under the current directory, as git does) and `--is-inside-work-tree`.
- Fix: `stash pop`/`stash apply` no longer fail with "requires clean working tree and index" merely because an untracked file exists -- git ignores untracked files here.
- Git parity: `status` detects renames -- `R  old -> new` in `--porcelain`/`--short` (and `RM` when the destination is also modified in the working tree), `renamed: old -> new` in the long format. A rewrite too dissimilar to be a rename stays `D` + `A`, as in git, and `status.renames=false` turns detection off. Verified byte-for-byte against `git status` over 750 randomized working-tree states covering renames, rewrites, modifications, deletions, mode changes and untracked directories.
- Fix: `blame` attributed lines to the wrong commits. Its LCS table was allocated but never zeroed, so line tracking ran on heap garbage; blame now uses git's own diff for line correspondence. Verified against `git blame` on randomized edit histories (99%+; the residual is a duplicate-line tie-break inside a hunk).
- Git parity: `status` reports a mode-only change (`chmod +x` with unchanged content) -- it previously compared blob ids only and showed nothing.
- Git parity: `status` collapses a wholly-untracked directory to `dir/` instead of listing every file inside it, and accepts `-uall`/`--untracked-files=all` to list them (plus `-u`/`-unormal`). A directory that also holds tracked files is still descended into, as in git.
- Fix: version could not open a submodule created by `git submodule add` at all (its `.git` file points upwards, `gitdir: ../.git/modules/<name>`, which the repository reader rejected). Submodule diffs, stats and merges work now.
- Git parity: `merge` of a submodule prints `Note: Fast-forwarding submodule <path> to <sha>` and moves only the gitlink, leaving the submodule's working tree untouched, as git does (`submodule.recurse` now defaults to false).
- Git parity: `diff`/`--stat` of a submodule bump shows `Subproject commit <sha>` rather than failing with "object not found".
- Git parity: a custom `merge.<driver>.driver` that exits non-zero now keeps its output as the merge result and marks the path conflicted (version previously threw the driver's result away and wrote its own conflict markers).
- Git parity: `merge.renormalize` re-runs the text clean filter on all three sides before merging, so line-ending churn on one branch no longer conflicts.
- Git parity: `merge` prints `Auto-merging <path>` for cleanly content-merged paths too, not only conflicted ones -- matching git's output line for line, including the ordering when a merge has both.
- Git parity: `merge-file` now folds two conflicts into one when the lines between them carry no letter or digit (git's merge-file runs xdiff a notch more aggressively than `git merge` does -- the ZEALOUS_ALNUM level); `merge` keeps git's three-line rule.
- Git parity: `-Xdiff-algorithm=patience` (and `merge-file --diff-algorithm=patience`) now runs git's real patience diff rather than an approximation, and `merge-file` accepts `--diff-algorithm=<myers|minimal|patience|histogram>` at all, which it previously rejected. All four algorithms are now byte-identical to git's for both commands.
- Fix: `merge` now leaves stage 1/2/3 index entries for a rename/modify conflict (the conflict markers were written but the index had no unmerged stages, unlike git).
- Git parity: `merge` (and `rebase`/`cherry-pick`/`revert`/`stash apply`) now use the **histogram** diff algorithm, which is what git's merge machinery actually uses -- only `merge-file` defaults to Myers. Two equally minimal edit scripts place hunk boundaries differently, so this decides where conflicts land: real merges are now byte-identical to `git merge` (previously ~96% on fuzzed merges; the earlier fuzzing only ever exercised `merge-file`, which hid this). `-Xdiff-algorithm=` still selects myers/minimal/patience/histogram explicitly.
- Git parity: `-Xignore-space-change`/`-Xignore-all-space`/`-Xignore-space-at-eol`/`-Xignore-cr-at-eol` now fold whitespace inside the diff itself, so a side whose only change is ignorable whitespace counts as unchanged and the merge takes the other side's file verbatim -- exactly as git does. Lines are still written out with their original whitespace.
- Git parity: a rename makes the conflict markers carry each side's path (`<<<<<<< HEAD:old.txt` / `>>>>>>> feature:new.txt`), as git does; renames to the same path keep the plain labels.
- Git parity: `version rerere diff` is implemented -- a unified diff of the recorded (normalized) preimage against the file as it stands now, byte-identical to `git rerere diff` both before and after a partial resolution.
- Git parity: the merge/diff engine behind `merge`, `merge-file`, `rebase`, `cherry-pick`, `revert`, and `stash apply` now reproduces git's own diff (a port of xdiff's `xdl_do_diff`: record classification, common-end trimming, `xdl_cleanup_records`, and Myers' divide-and-conquer with git's heuristics) instead of version's LCS. Two equally minimal edit scripts can put a hunk boundary in different places, which moves where a conflict lands; matching git's script choice removes the last source of divergence. `version merge-file` is now byte-identical to `git merge-file` on 100% of fuzzed 3-way merges (previously ~88%), across every conflict style and favor mode, LF and CRLF, up to 2500-line files.
- Git parity: merge conflicts in a CRLF file now write CRLF-terminated conflict markers (matching git's `is_cr_needed`), instead of LF markers in an otherwise CRLF file; LF files are unchanged. Verified byte-for-byte against `git merge`/`git merge-file` for the merge/diff3/zdiff3 styles, mixed endings, missing final newlines, and add/add.
- Git parity: `merge` (and `rebase`/`cherry-pick`/`revert`/`stash apply`) now produce git's line-level conflicts instead of a single whole-file conflict block: cleanly-merged hunks stay outside the `<<<<<<<`/`=======`/`>>>>>>>` markers, adjacent conflicts less than three common lines apart combine into one hunk, add/add conflicts are merged against an empty base, and the markers carry git's labels (`HEAD`, the abbreviated merge-base oid under `--diff3`/`--zdiff3`, `Updated upstream`/`Stashed changes` for stash, `<abbrev> (<subject>)` for a replayed commit). `-Xours`/`-Xtheirs` now resolve only the conflicting hunks, keeping the other side's clean changes (previously the whole file was taken, silently dropping them), and the `union` merge attribute unions per hunk. The conflicted file, the unmerged index stages, and the rerere rr-cache id/preimage are byte-identical to `git merge`. Note: edits on adjacent lines now conflict, matching git (version used to merge them).
- Git parity: new `version rerere [status|remaining|diff|forget <pathspec>|clear|gc]` -- exposes git's reuse-recorded-resolution plumbing; and version's rerere store is now git-format (`Version.Merge.Rerere_Conflict_Id`): rr-cache keys are the per-file conflict-content SHA-1 (`min_side\0max_side\0`, sides sorted so a conflict resolves regardless of merge direction), preimages are git-normalized (context outside bare markers), and MERGE_RR is NUL-terminated. `status`/`remaining`/`clear`/`forget` match git; the rr-cache hash equals git's for git-granularity conflicts (see note).
- Git parity: new `version merge-file [-p] [-L <label>]... [--diff3|--zdiff3] [--ours|--theirs|--union] [--marker-size=<n>] <current> <base> <other>` -- a hunk-level 3-way text merge (new `Version.Merge.Merge_File`, a port of git's xdiff `xdl_do_merge`): clean regions stay outside `<<<<<<<`/`|||||||`/`=======`/`>>>>>>>` markers, conflicts separated by <=3 common lines are combined (default style only), and `--diff3`/`--zdiff3`/favor modes/labels/marker-size all match. Writes back to <current> unless `-p`; exit status = conflict count. Byte-identical to `git merge-file` across fuzzed 3-way merges (see the diff-engine entry above: version now reproduces git's own edit script, not merely an equally minimal one).
- Git parity: new `version show-branch [--list] [<branch>...]` -- prints git's branch-comparison matrix (a `!`/`*` header per branch, an N-dash separator, then one `*`/`+`/`-`/space marker column per branch for every commit back to the branches' merge base, each named by first-parent distance `ref`/`ref^`/`ref~n`) and the `--list` head summary; byte-identical to `git show-branch` for branches diverging from a common base without merge commits in the shown range (merge commits inside the range use git's convergence traversal + `^2` naming, not yet modelled).
- Git parity: new `version bisect start|good|bad|new|old|skip|reset|log|terms` -- binary-searches history for the first bad commit, managing `refs/bisect/*`/`BISECT_START`/`BISECT_TERMS`/`BISECT_LOG`, checking out each computed midpoint (`Bisecting: N revisions left to test after this (roughly M steps)`) and printing `<oid> is the first bad commit` with the commit's `--stat` on convergence -- byte-identical to `git bisect` across the selection, counts, custom/`new`-`old` terms, log format, and reset transcript (`run`/`replay`/`visualize` not yet implemented; `skip`'s next-commit choice may differ on ties).
- Git parity: new `version replace [-f] <object> <replacement>` / `replace -d <object>...` / `replace [-l] [--format=short|medium|long] [<pattern>]` -- manages `refs/replace/*`, and object reads now follow the replacement (honoring `GIT_NO_REPLACE_OBJECTS`), matching git including the `-> `/`(type)` list formats and the `Deleted replace ref '<oid>'` message.
- Git parity: new raw-format diff plumbing -- `version diff-tree [-r] [--root] (<tree> <tree> | <commit>)`, `version diff-index [--cached] <tree-ish>`, and `version diff-files` -- emitting git's `:<mode1> <mode2> <sha1> <sha2> <status>\t<path>` lines, byte-identical to git (recursion, the commit-then-raw form, and the staged/unstaged working-tree distinction).
- Git parity: new `version get-tar-commit-id` -- reads a tar archive on stdin and prints the commit id from its pax global header (exit 1 when absent); `version archive` of a commit now embeds that header, so the id round-trips through version's own tars and git's.
- Git parity: new `version fmt-merge-msg [-F <file>]` -- formats a merge-commit message from FETCH_HEAD (stdin or `-F`), matching `git fmt-merge-msg` across branch/tag grouping by source, the " into <branch>" suffix, and inlined annotated-tag messages.
- Git parity: new `version mktag` -- reads a tag object on stdin, validates its object/type/tag/tagger header and that the referenced object exists with the declared type, writes the tag verbatim, and prints its id (oid-identical to `git mktag`).
- Git parity: new `version mktree [--missing]` -- reads `<mode> <type> <sha> TAB <path>` tree entries on stdin, sorts them into git tree order, writes the tree object, and prints its id (oid-identical to `git mktree`); referenced objects are verified present unless `--missing`.
- Git parity: new `version check-ref-format [--normalize] [--allow-onelevel] [--no-allow-onelevel] [--refspec-pattern] <refname>` and `--branch <name>` -- validates a refname against git's grammar (exit 0/1), prints the normalised name, or resolves a branch shorthand (`@{-N}` via the HEAD reflog); byte/exit-code identical to `git check-ref-format`.
- Git parity: new `version stripspace [-s|--strip-comments | -c|--comment-lines]` -- cleans a message read from stdin (collapse blank runs, strip trailing whitespace, trim edge blanks; `-s` drops comment lines, `-c` comments every line), byte-for-byte with `git stripspace`.
- Git parity: new `version interpret-trailers [--trailer <t>] [--where after|before] [--only-trailers] [--only-input] [--unfold] [--parse] [--in-place] [<file>...]` -- adds/extracts commit-message trailers from stdin or files, byte-for-byte with git across the common shapes (append to an existing block, open a new block, `--only-trailers`, `--parse` folding, `token=value`/empty-value normalisation).
- Git parity: new `version maintenance run [--task=<task>] [--quiet] [--auto]` -- performs repository maintenance silently (object tasks gc/loose-objects/incremental-repack map onto version's GC; the default runs gc), rejecting an unknown `--task` with git's `'<task>' is not a valid task`. The OS-scheduling subcommands (start/stop/register/unregister) are intentionally unsupported.
- Git parity: new `version hook run [--ignore-missing] <name> [-- <args>...]` -- runs the named repository hook with the given arguments (streaming its stdout/stderr) and propagates its exit code; a missing hook reports `cannot find a hook named <name>` and exits 1 unless `--ignore-missing`. Matches `git hook run`.
- Git parity: new `version switch` -- `-c`/`-C <new> [<start>]` (create + switch, "Switched to a new branch"), `<branch>` (symref switch, "Switched to branch"), `-` (previous branch via HEAD reflog), and `--detach [<commit>]` ("HEAD is now at"), including the "Previous HEAD position was" advisory git prints when leaving a detached HEAD -- byte-verified against git.
- Git parity: added `version var GIT_AUTHOR_IDENT`/`GIT_COMMITTER_IDENT`/`GIT_EDITOR` (honouring GIT_AUTHOR_DATE/GIT_COMMITTER_DATE), `version count-objects`, `version name-rev [--tags] COMMIT...`, `rev-parse <ref>@{n}` reflog revisions, and the `%(upstream)`/`%(upstream:short)` for-each-ref atoms -- each byte-verified against git.
- Git parity: `version cat-file --batch-all-objects` (with `--batch-check`/`--batch`) now enumerates every object -- loose and packed, merged and sorted by oid via `Version.Pack.All_Pack_Objects` -- byte-identical to git.
- Git parity: `version log --stat` shows a per-commit diffstat, byte-identical to git (root commits diffed against the empty tree). (`whatchanged` is intentionally not added -- upstream git has deprecated it in favour of `log --raw`.)
- Git parity: `version tag --sort=<key>` (and `tag -l --sort=<key>`) now sorts the tag list via for-each-ref (e.g. `--sort=-creatordate`), matching git.
- Git parity: `version rev-list` gained `--all` (walk every ref), `version branch` now accepts `-v`/`--verbose` (7-hex tip + subject, git's padding) and `-a`/`-r`/`--all`/`--remotes`, and the verbose branch listing no longer emits a spurious trailing blank line or a 12-hex id.
- Git parity: new `version merge-base COMMIT COMMIT` (with `--all` and `--is-ancestor`), and `version grep` gained `-c` (per-file match counts) and `-l` (matching file names).
- Git parity: `version diff` gained `--name-only` and `--name-status`; `version log` gained `--format=<fmt>`, `--pretty=format:<fmt>`, and `--pretty=tformat:<fmt>` (byte-exact with git, including trailing-newline semantics).
- Git parity: `version rev-parse` gained `--short` (7-hex abbreviation) and now accepts it bundled with `--abbrev-ref`.
- Git parity: broad plumbing/porcelain byte-parity sweep. Bare `version branch` and `version tag` now list (like git); `tag -l`/`--list` alias added. `show-ref` now honours `--heads`/`--tags` filters instead of always printing every ref. `ls-files -s`/`--stage` prints git's `<mode> <object> <stage>\t<path>`. `rev-list` gained `--max-count=<n>`/`-n <n>`. `cat-file -p <tree>` now lists one level (subtrees as `tree`, six-digit modes) instead of recursing. `git log`'s Date line no longer space-pads a single-digit day (`Feb 1`, not `Feb  1`). `describe --tags` prefers an annotated tag over a lightweight one at equal distance. `for-each-ref --sort=creatordate` now uses an annotated tag's tagger date (it was reading a non-existent committer line and mis-sorting tags).
- Git parity: `version shortlog` now lists each author's subjects oldest-first (chronological, matching git; they were reversed), breaks `-n` count ties by author name (git's stable order), and accepts bundled short flags like `-sn`. (`-e` e-mail grouping is still unimplemented and rejected rather than silently mis-grouped.)
- Git parity: `version blame` default output now matches `git blame` byte-for-byte — the boundary `^` marker on root-commit lines, the `(<author> <iso-date> <lineno>)` column block, left-padded author names, and right-aligned line numbers — instead of the previous bare `<abbrev> <lineno>) <line>`. (Line attribution was already correct; only the annotation format changed.)
- Git parity: `version describe` now names a commit relative to annotated tags only (git's default) and accepts `--tags` to also consider lightweight tags; with no eligible tag it fails like git ("No names found…" or "No annotated tags can describe…; try --tags"). `version save` gained `-S[<keyid>]`/`--gpg-sign[=<keyid>]`/`--no-gpg-sign` (and honours `commit.gpgSign`), and `version push REMOTE` with no refspec now follows `push.default` (simple/current/upstream/nothing) instead of erroring.
- Bug fix: `version mv FILE DIR/` (destination directory with a trailing slash) now moves the file into the directory like git, instead of building a `DIR//FILE` path that failed with "empty path component" and moved nothing.
- Git parity: `version submodule` gains `foreach`, `sync`, and `deinit`. `foreach [--recursive] COMMAND` runs a shell command in each populated submodule (path-sorted, printing `Entering '<path>'`) with git's `$name`/`$sm_path`/`$displaypath`/`$sha1`/`$toplevel` environment; `sync [--recursive]` copies each submodule's `.gitmodules` URL into `submodule.<name>.url` and the submodule's `remote.origin.url` (`Synchronizing submodule url for '<path>'`); `deinit [--force] [--all|PATH...]` empties the working tree and removes the submodule config while keeping `.gitmodules` (`Cleared directory`/`unregistered`). Byte-verified against git. Also fixed `status` reporting a submodule/linked-worktree `.git` *gitfile* as an untracked `?? .git` (git excludes `.git` whether it is a file or a directory).
- Git parity: `version fetch --deepen N` and `version fetch --unshallow` are now supported. `--deepen N` extends a shallow repository's boundary by N commits (requesting the `deepen-relative` capability and echoing the current boundary); `--unshallow` fetches the complete history and removes `.git/shallow` (failing on a non-shallow repo). `--depth`/`--deepen`/`--unshallow` are mutually exclusive. Verified against a live `git http-backend` server: the deepened boundary and full history match git byte-for-byte and `git fsck` is clean.
- Bug fix: fetched packs are now written under git's canonical `pack-<checksum>` name instead of a fixed `tmp-version-fetch.pack`, so a second network fetch/clone into the same repository no longer truncates the previous pack and loses its objects (this previously corrupted any shallow re-fetch and any repeated fetch).
- Git parity: `version sparse-checkout` (and the existing `sparse` alias) now implements git's full command — `set`/`add` default to **cone mode**, writing git's cone patterns (`/*`, `!/*/`, `/dir/`, plus `!/dir/*/` for nested directories), setting `core.sparseCheckout`/`core.sparseCheckoutCone`, materializing the working tree, and setting git **skip-worktree** bits on the excluded index entries (emitting a version-3 index) so `git status`/`ls-files -t` round-trip a version-created sparse checkout byte-for-byte. Adds `reapply`; `--no-cone` writes raw patterns; `list` prints cone directory names (and fails with `this worktree is not sparse` when disabled); `disable` now keeps the pattern file (git parity) and clears skip-worktree bits; `set` with no directories is accepted (top level only). Fixed nested cone read inclusion (a parent directory's own files are kept while its sibling subtrees are excluded). Byte-verified against `git sparse-checkout` for `set`/`add`/`list`/`disable`/`reapply` and for git reading a version-made sparse checkout.
- Git parity: `version config get` no longer emits a spurious trailing blank line (byte-exact with `git config`).
- Git parity: `version clone` of a remote whose HEAD points to a branch that was never fetched (a dangling remote HEAD — e.g. a bare repo whose configured default branch was never pushed) now warns `remote HEAD refers to nonexistent ref, unable to checkout` and completes with an unborn HEAD (points at the missing default branch, no checkout, no `origin/HEAD`, remote branches still fetched), matching `git clone` byte-for-byte, instead of failing with `missing remote-tracking ref for default branch`.
- Git parity: `version config get`/`list`/`keys` now read git's full config scope stack — system (`/etc/gitconfig` or `GIT_CONFIG_SYSTEM`, suppressed by `GIT_CONFIG_NOSYSTEM`), global (`$XDG_CONFIG_HOME/git/config` then `~/.gitconfig`, or `GIT_CONFIG_GLOBAL` replacing both), then local `.git/config` and per-worktree `config.worktree` — instead of local-only. Byte-verified against `git config --list` (including `~/.gitconfig`/`/etc/gitconfig`) and against git for scope precedence and the `GIT_CONFIG_NOSYSTEM`/`GIT_CONFIG_GLOBAL` overrides. Env-injected config (`GIT_CONFIG_COUNT`) is not yet consulted; `set`/`unset` still write only the local config.
- Git parity: `version config` now follows `[include]` and `[includeIf]` directives when reading the effective config, so `config get`/`config list` resolve values pulled in from included files. All four conditions are supported — `gitdir:`, `gitdir/i:` (case-insensitive), `onbranch:`, and `hasconfig:remote.*.url:` — the include `path` is resolved relative to the including file (with `~` expansion), the directive itself stays a readable key (`include.path`), and a single-valued lookup now returns git's **last** matching value (not the first). Byte-verified against git for `config get` and `config --list`.
- Git parity: `version fetch <remote> <ref>` (explicit single ref) now records `.git/FETCH_HEAD` and prints git's ` * branch <ref> -> FETCH_HEAD` form (plus the opportunistic tracking-ref line) without the spurious tag lines version previously emitted; byte-verified against `git fetch <remote> <ref>`.
- Git parity: version pathspecs now accept the `:(icase)` magic (case-insensitive path match), and `version ls-files <pathspec>...` now filters its output by the given pathspecs instead of ignoring them. Byte-verified against git.
- Git parity: `version config list`/`config keys` no longer emit a spurious trailing blank line — the output is now byte-exact with `git config --list`/`--name-only` (variable names are also lower-cased as git canonicalises them, subsection case preserved).
- Git compatibility: `version` now operates on git's cone-mode sparse-checkout repositories backed by a sparse (v3) index — previously every command errored (`unsupported index: only version 2 is supported`, then `absolute pathspecs are not allowed: /*`). The index reader now accepts version 3 (the extended-flag format git writes for a sparse index) and expands its sparse directory (`sdir`) entries; git's cone patterns (`/*`, `!/*/`, `/dir/`) are interpreted by their cone semantics rather than as version pathspecs; and `status`/`diff` no longer report sparse-excluded (skip-worktree) paths as deleted. `status`, `ls-files`, `log`, `diff`, `diff --stat`, and `cat-file` now match git on such repositories.
- Git parity: `version merge` conflict output now byte-matches git across every conflict type — content, add/add, modify/delete, delete/modify, rename/delete, rename/rename, rename/add, unrelated-histories, and **file/directory** — verified differentially (`rerere.enabled=false`). Two fixes: the spurious `Auto-merging <path>` line is gone for modify/delete and file/directory conflicts (git prints it only when it runs the content three-way merge); and a file/directory collision now resolves the git way — the losing file is renamed to `<path>~<label>` (label `HEAD` for the current side, else the incoming merge name), the directory's files are left clean at stage 0, and the working tree, index stages, `status`, and the `directory in the way of <path> from <label>; moving it to <path>~<label> instead.` message all match git byte-for-byte.
- Git parity: `version fetch` (and `pull`) now print git's transfer summary to stderr — the `From <url>` line (trailing `.git` stripped) followed by per-ref lines matching git's column layout (summary field `2·abbrev+3`, ref column `min 10`): ` <old>..<new>  <name> -> origin/<name>` for fast-forward updates, ` + <old>...<new> … (forced update)` for non-fast-forwards, and ` * [new branch]`/`[new tag]` for new refs; nothing is printed when already up to date. Replaces the previous non-git `fetched <remote>` line. Byte-verified against git for single/forced updates, new branch + new tag, multi-branch, up-to-date, and bare `pull`.
- Git parity: `version clone` now writes `refs/remotes/origin/HEAD` (a symref to the remote's default branch), as `git clone` does. This makes the fetch summary order refs exactly like git (default branch first, then heads then tags, byte-verified including a non-`main`/`master` default), and lets `<remote>` resolve to the default branch.
- Git parity: explicit `version pull <remote> <branch>` now reports git's FETCH_HEAD form — ` * branch <name> -> FETCH_HEAD` (unconditional, even when up to date) plus the opportunistic ` <old>..<new> <name> -> origin/<name>` tracking line — and records `.git/FETCH_HEAD`. `version pull <remote> <branch>` now byte-matches `git pull <remote> <branch>` end-to-end (both updated and up-to-date).
- `Version.Refs.Resolve_Ref` now follows loose symbolic refs (`ref: …`), not only reftable symrefs — so `refs/remotes/*/HEAD` and other loose symrefs resolve instead of raising "invalid ref object id".
- Git parity: `for-each-ref <prefix>/` (a trailing-slash, non-glob pattern) now lists the refs under the prefix instead of failing with an internal error (a fixed-length `String` reassignment raised `Constraint_Error`).
- Git parity: `version merge` (and `pull`'s merge phase) now print git's full success output — the `Updating <old>..<new>` line before a fast-forward, the `--stat` diffstat plus `--summary` (`create`/`delete mode`) block after `Fast-forward`/`Merge made by the 'ort' strategy.`, and octopus `Fast-forwarding to:`/`Trying simple merge with` progress — byte-verified against git for fast-forward, clean merge, `--squash` (now in git's line order), `--no-stat`, and 2-/3-way octopus. Replaces the previous hand-rolled, non-git stat (`N files changed` with no diffstat/summary and wrong pluralization). The merge diffstat/summary reuses the unified-diff engine's `--stat`/`--summary` renderer.
- `clone`/`fetch`/`push`/`pull` (and LFS transfers) over HTTPS now actually use HTTP/2 against real servers: the git smart-HTTP transport advertised HTTP/2 via ALPN but never enabled the client's multiplexed stream model, so every HTTP/2 response failed with `HTTP2_MULTIPLEXING_UNSUPPORTED` — a `version clone https://github.com/...` fell over instead of downloading. Enabling `Enable_Multiplexing` makes HTTP/2 clone/fetch work end-to-end (verified against GitHub: byte-identical HEAD and `git fsck`-clean objects); plain-HTTP remains HTTP/1.1.
- Git parity: `version diff`/`show` now emit a real minimal unified diff — a Myers/LCS edit script with context lines and hunk splitting, the `diff --git` header, and the `index <old>..<new> <mode>` line — replacing the previous whole-file `-`/`+` replacement. New/deleted/binary files, no-newline-at-EOF markers, and commit-to-commit diffs match `git` byte-for-byte.
- Git parity: added `version diff --stat` and `version show --stat` (git's per-file change bars plus the `N files changed, X insertions(+), Y deletions(-)` summary).
- Git parity: `version log`/`show` now render author dates in git's default format (`Www Mmm D HH:MM:SS YYYY ±HHMM`, in the commit's timezone) instead of the raw `<epoch> <tz>`.
- Git parity: added `version log -<n>` / `-n <count>` / `--max-count=<n>` to limit the number of commits shown.
- Git parity: `version log --oneline` now abbreviates commit ids to git's shortest-unique length (7-char floor) instead of a fixed 12 characters.
- Git parity: `status --porcelain`/`-s`, `log`, `diff`, `show`, and `cat-file` output is now byte-exact — a spurious trailing newline (GNAT's `Text_IO.Put` left the cursor mid-line, so the runtime appended a terminator at exit) is gone, and `cat-file -p` of a blob without a final newline no longer gains one.
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
