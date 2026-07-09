# Git parity roadmap (prioritized)

Scope reminder: `version` targets file-level interoperability with real Git
repositories plus the common workflows, not full `git` CLI parity (see
`COMPATIBILITY.md`). The gaps below are ordered by user impact. Functionality
lands in `versionlib`; the command surface is wired in the `version` CLI.

## Tier 1 - everyday porcelain (highest impact)
- `reset` (`--soft`/`--mixed`/`--hard [<commit>]` and `reset [<commit>] -- <paths>`): **implemented**.
- `pull`: **implemented** (`pull [--rebase] [--ff-only] [REMOTE [BRANCH]]`).
- `reflog`: **implemented** (`reflog [show] [REV]`, git-identical output).
- `mv` (tracked rename): **implemented**.
- `clean` (remove untracked files, `-n`/`-d`/`-x`): **implemented**.

## Tier 2 - patch & offline transport
- Patch workflow: `apply`, `format-patch`, `am`, `cherry`, and `range-diff` **implemented**; `send-email` out of scope (SMTP). (Tier 2 complete.)
- `bundle`: **implemented** (`create`/`verify`/`list-heads`/`unbundle`; git-interoperable). `unbundle` unpacks the packfile into the object store and prints ref lines (refs not created). **Clone-from-bundle (`clone <bundle>`) implemented** — a local plain-file source is unpacked as a bundle: objects into the store, bundle refs as `refs/remotes/origin/*` + tags, `origin` set to the bundle path, and the default branch (git's `guess_remote_head`: prefer main/master carrying HEAD's id, else the HEAD-id branch) checked out. Verified against git both directions (`fsck`-clean).

## Tier 3 - inspection
- `blame`, `describe`, `grep`, `notes`, `shortlog`: **implemented**. (Tier 3 complete.)

## Tier 4 - rebase depth
- Interactive (`-i`): **implemented (full action set)** — pick/drop/reorder/squash/fixup/reword/edit/exec via the sequence editor. Reword opens the message editor (git `cleanup=strip`, empty-message abort, survives a conflict pause). Edit stops with a clean tree at the commit (branch moved onto it) for amending, then `--continue` replays the rest; a conflicting edit stops only for the conflict (git parity). Exec runs `<command>` at its todo position (interleaved before/between/after picks); a non-zero exit stops the rebase with a non-zero status, and `--continue` advances past the failed exec without re-running it (git parity). Reword/edit/exec + squash is rejected.
- Root (`--root`): **implemented** — `rebase --root --onto NEWBASE` (root-commit replay onto a new base) and bare `rebase --root` (recreate the branch from a parentless root onto an empty base, preserving trees/messages/authors).
- Merge-preserving (`--rebase-merges`): **implemented** for two-parent and octopus (>= 3 parent) merges (topological replay recreating merges; octopus via git's iterated merge-octopus strategy), with **resumable conflict-pause/continue** for linear and two-parent-merge conflicts (`--continue`/`--abort`; octopus conflicts abort, matching git). Still non-interactive (auto topological replay; no editable `label`/`reset`/`merge -C` todo).

## Tier 5 - remote / transport
- **`push --tags` to non-local remotes: implemented** (HTTP + SSH receive-pack, one ref per request, no-clobber on differing remote tags).
- **`push --force` (non-fast-forward branch update): implemented** (local, HTTP, SSH).
- **`push --delete REMOTE REF` (delete a remote branch/tag): implemented** (local, HTTP, SSH).
- **Arbitrary refspecs `push REMOTE SRC:DST` (and `+SRC:DST`, `:DST`): implemented** (local, HTTP, SSH).
- **Forced tag overwrite `push --tags --force`: implemented** (local, HTTP, SSH).
- **`remote.<name>.push` config defaults (`push REMOTE` with no refspec): implemented** (multi-valued; each parsed like a CLI refspec).
- **Multiple refspecs in one `push` invocation and wildcard (`*`) refspecs: implemented** — several refspecs (and `--delete REF...`) are processed per invocation and `refs/heads/*:refs/heads/*` expands to one push per matching local ref (verified differentially). Updates go out as separate ref requests (git's default non-atomic end state).
- **`push --atomic` (single batched request, all-or-nothing): implemented** (local, HTTP, SSH) — all ref updates/deletes go in one receive-pack request advertising the `atomic` capability; a rejected non-fast-forward (unless `--force`) or any server `ng` aborts the whole push, leaving the remote unchanged. Local pushes apply every update in one `Ref_Transaction`. Refuses if the remote does not advertise `atomic`. Verified against real git (`git-http-backend`) both for batched success and all-or-nothing rejection. (`--atomic --tags` is rejected; use explicit refspecs.)
- **Bare `:` / `push.default=matching` refspec: implemented** — `push REMOTE :` (and a bare `push REMOTE` when `push.default=matching`) updates every remote branch that shares a name with a local branch, creating none. Remote branches are discovered per transport (local repo scan, or the receive-pack advertisement over HTTP/SSH via `Version.Receive_Pack.Discover_Http`/`Discover_Ssh`). Verified against git (local + `git-http-backend`).
- Optional: HTTP/3, h2c, server-side hook management / `daemon` (largely out of scope).

## Tier 6 - object/ref formats & extensions
- **`worktreeConfig` extension: implemented (read + write)** — the per-worktree `config.worktree` is layered over the common config when reading, and `config set/unset --worktree` writes to it when `extensions.worktreeConfig` is enabled (common-config fallback otherwise).
- **Partial clone refinements: implemented** — `clone --filter=SPEC` negotiates the filter over HTTP/SSH (arbitrary specs) and evaluates `blob:none`/`blob:limit`/`tree:<depth>` locally (selective copy), matching git's keep-sets; see COMPATIBILITY. Remaining: local `sparse:oid` evaluation (negotiated remotely). Note version applies local filters unconditionally, whereas stock git ignores `--filter` for plain local paths and needs `uploadpack.allowFilter=true` for `file://`.
- **SHA-256 object format: implemented** — `init --object-format=sha256` creates git-compatible SHA-256 repositories (64-hex / 32-byte ids, wider pack `.idx`, SHA-256 pack/index/commit trailers); read+write, local and smart HTTP/SSH transport (format negotiated via the `object-format=sha256` capability), verified end-to-end against system git (fsck/verify-pack/bundle-verify clean; version reads git-made sha256 repos). See [SHA256_SCOPE.md](SHA256_SCOPE.md) for the phase log. One format per repo (never mixed).
- **Reftable ref storage: implemented (read + write + compaction)** — `Version.Reftable` parses git's binary table stack and `Version.Reftable.Writer` emits git-readable tables (ref block + restart points + CRC32 footer). All ref reads (`Refs`/`Ref_Cache`/`Tags`/`Ref_Format`) and writes (`Ref_Transaction`, HEAD, branch switch) route through the backend for `extensions.refStorage = reftable`; `init --ref-format=reftable` creates such repositories; and the reflog is stored in (and read from) zlib-compressed log blocks via `Version.Reflog`. Writes are incremental (one small table appended per transaction) with **geometric auto-compaction** keeping the stack bounded (O(log n) tables), preserving tombstones and reflog history through merges. Verified against git 2.54 (bidirectional, `fsck`-clean, `git reflog`, mixed-op stress).

## Tier 7 - filters, attributes, archive
- `core.autocrlf` and `.gitattributes` text/eol: **implemented** — `core.autocrlf` (true/input/false), `core.eol`, and top-level `.gitattributes` `text`/`-text`/`text=auto`/`eol=lf`/`eol=crlf` (plus old `crlf` synonyms and `binary`) drive CRLF↔LF conversion on check-in, checkout, and status, with NUL-byte binary autodetection. Remaining: nested per-directory `.gitattributes`, `ident`, and `export-subst` in `archive`; full macro-attribute expansion.
- Git LFS materialization: **implemented for the local round trip** — clean caches media and stores a pointer; smudge fetches/materializes from a local-dir, HTTP-batch, or SSH LFS store; push uploads referenced media to a local-dir store (git-lfs pre-push). Remaining: HTTP/SSH LFS *upload* on push, and LFS locking.
- `archive` compressed output: **implemented** — `--format=tar.gz`/`tgz` (and `.tar.gz`/`.tgz` output-suffix inference) emit a standard gzip-wrapped tar. `export-subst` keyword expansion remains pending (folded into the `.gitattributes` work below).

## Tier 8 - plumbing surface
- **Implemented:** `cat-file`, `hash-object`, `rev-parse`, `rev-list`, `ls-files`, `ls-tree` (one-level + `-r`), `update-ref`, `symbolic-ref` (read + set), `show-ref`, `for-each-ref`, `write-tree`, `read-tree`, `commit-tree`.
- **`for-each-ref` richer: implemented** — `--format=<fmt>` atom interpolation, `--sort=<key>` (asc/desc, chronological dates), `--count`, and shell-glob (WM_PATHNAME) patterns over all `refs/` (loose + packed).
- **`cat-file --batch` / `--batch-check`: implemented** — stdin-driven batch output with default and custom (`%(objectname)`/`%(objecttype)`/`%(objectsize)`/`%(rest)`) formats and `missing` handling.
- **`update-index`: implemented** — `--add`/`--remove`/`--force-remove`, `--cacheinfo` (comma and three-arg forms), `--chmod=(+|-)x`, plain tracked-path update, `--`/`--refresh`.
- Tier 8 plumbing surface is now complete.

## Ecosystem
- **Commit/tag sign + verify: implemented** — commit signing (`-S`/`commit.gpgsign`), annotated-tag signing (`tag -s`/`-u`), `verify-commit`/`verify-tag`, `merge --verify-signatures` (refuses an unverifiable merge target), and `log --show-signature` (interleaves gpg's verification lines after each signed commit header) via gpg (bidirectionally verified against real git). (Sign/verify complete.)
- **Credential helpers: implemented** — `credential fill/approve/reject` drive `credential.helper` programs (git get/store/erase protocol). Remaining: automatic invocation from the HTTP transport auth path, and credential-manager/`cache`-daemon integration.

---

# Historical phase notes

## Phase 38 Windows portability depth

Phase 38 hardens Windows-specific behavior without adding new Git features. The current scope centralizes drive-path detection, keeps Windows absolute and drive-relative paths out of SSH/submodule scp-like classification, normalizes backslash input to repository slashes, rejects duplicate separators as empty path components, rejects Windows-invalid repository-relative paths and ref path components, detects simulated case-insensitive collisions before writes, including common UTF-8 Latin composed/decomposed accent collisions, uses Windows-safe atomic replacement semantics for refs/state/admin files, bounds runtime path lengths without silent truncation, rejects rooted backslash escapes, preserves CRLF/binary bytes exactly, defaults `core.filemode` according to platform executable-bit support, accepts Windows absolute `.git` gitdir text where repository/worktree/submodule indirection expects filesystem paths, keeps production hook execution on direct argv spawning without POSIX helper-program probes, strips Windows `file:///C:/...` file remotes to usable drive paths, centralizes portability-sensitive directory renames and recursive directory deletion, hardens working-tree scan relative path derivation for native Windows separators, and routes repository admin path joins through `Version.Files.Join`.

Deferred items remain full `core.autocrlf`, NTFS alternate-stream parity beyond invalid `:` in repository-relative paths, full host-specific Unicode normalization/casefolding beyond common UTF-8 Latin accent collision preflight, Windows credential manager integration, PowerShell hook execution, long-path `\\?\` support, Windows symlink checkout parity, and exact Git-for-Windows behavior parity.

## Phase 22 portability scope

Phase 22 centralizes practical cross-platform behavior without adding new Git features. Implemented scope includes platform policy helpers, portable file helper expansion, Windows-safe repository path validation, simulated case-insensitive path collision detection before whole-tree restore/checkout, byte-preserving CRLF/binary IO tests, and lockfile-style atomic replacement through `Version.Files`.

Deferred items remain full `core.autocrlf`, `.gitattributes`, Windows symlink object checkout parity, full host-specific Unicode normalization parity beyond common UTF-8 Latin accent collision preflight, Windows long-path registry behavior, advanced submodule workflows, advanced worktree parity, and platform credential helpers.


## Phase 40 - Archive export

Added repository archive creation through `version archive`, with TAR and ZIP writers, revision/tree-based export, pathspec filtering, safe root prefixes, deterministic metadata, and safe submodule gitlink placeholders. Archive output is generated from committed objects rather than the working tree or index.
