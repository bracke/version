# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`version` is a Git-compatible version-control tool written in Ada 2022, built with Alire/GNAT. It reads and writes a real `.git` directory and is validated against the system `git` command. This directory is **not** itself a git repository — it is the source for a VCS.

**Two crates:** all functionality lives in the **`versionlib`** library crate at `../versionlib` (every `Version.*` package). This `version` crate is the **CLI only** — `src/main.adb` plus `Version.CLI` and its children (`Version.CLI.Arguments/Help/Progress`) — and implements every command by calling into `versionlib`. Nothing in `versionlib` depends on the CLI.

## Build, test, lint

- This crate enforces GNAT 15 through Alire with `gnat_native = "=15.2.1"` in
  every active manifest. Do not run plain system GNAT, GPRBuild, GNATprove,
  GNATdoc, or related `gnat*` tools from `PATH`.
- Before building or testing, run `alr exec -- gnatls --version`; it must report
  `GNATLS 15.x`.
- Build the CLI: `alr build` (resolves and builds `versionlib` automatically; executable is `bin/main`).
- Build the library alone: `(cd ../versionlib && alr build)`.
- Tests are **two separate AUnit crates**:
  - Library/functionality suite: `(cd ../versionlib/tests && alr build) && (cd ../versionlib/tests && ./bin/tests)`.
  - CLI suite (CLI parsing, hooks, docs, CLI-integration): `(cd tests && alr build) && ./tests/bin/tests` — **run from this `version/` dir** (the CLI-integration tests invoke `bin/main` and the docs tests read `docs/`/`README.md` relative to CWD).
- Build tools: `alr exec -- gprbuild -P tools/tools.gpr`
- No separate formatter/linter — Ada style and warnings come from `-gnaty*` / `-gnatwa` flags in each crate's generated config. Keep builds warning-clean; clear warnings in code you touch.

## Dependencies

`versionlib`'s `alire.toml` pins `httpclient`, `zlib`, `i18n`, and `ssh_lib` to **sibling directories** (`../httpclient`, `../zlib`, `../i18n`, `../sshlib`). This `version` crate depends only on `versionlib` (pinned to `../versionlib`), which brings the rest transitively. The CLI executable links `-lssl -lcrypto`, so OpenSSL dev libraries are required.

## Code style (differs from defaults)

Enforced by GNAT flags, not a formatter — match the existing code:
- Ada 2022 (`-gnat2022`), UTF-8 source.
- 3-space indentation, max line length 120 (`-gnaty3`, `-gnatyM120`).
- No tabs, no trailing blanks, no extra parentheses; overriding subprograms marked explicitly (`overriding`).
- All warnings and validity checks are on (`-gnatwa -gnatVa`) and treated as the bar — don't introduce new ones.

## Architecture

All `Version.*` functionality packages live in `../versionlib/src`, organized by domain ownership; see `docs/ARCHITECTURE.md` for the authoritative map (`Version.Objects`, `Version.Refs`, `Version.Staging`, `Version.Transport`, `Version.Diff`, replay ops, etc.). The CLI (`Version.CLI*` + `main.adb`) in this crate's `src/` only parses arguments and delegates to those packages — add new behavior in `versionlib`, then wire it into the CLI. Design is cache-aware for scalability (per-command object/tree/ref/pack-index caches) — avoid quadratic lookups and spurious re-reads. `docs/` is comprehensive; consult `COMMANDS.md`, `COMPATIBILITY.md`, and `REPOSITORY_FORMAT.md` before changing behavior.

## Working in this repo

- **Verify against real Git.** Compatibility means matching the system `git` command's behavior and on-disk format, not just internal consistency. Tests use `git` for end-to-end checks.
- **Run both AUnit suites** after a change before reporting it done: the `versionlib` functionality suite and this crate's CLI suite (see Build, test above). Library changes → run the versionlib suite; CLI changes → run this one.
- **Add a CHANGELOG.md entry** for every behavioral change — a one-line entry at the top, matching the existing terse "Git parity" phrasing.
- **Run `tools/bin/check_documentation_coherence`** when touching `docs/` or command behavior.
- **There is no release freeze.** The project has not been released, so there is no frozen contract and no backward-compatibility burden — prefer real git behavior over any prior "frozen" output, and update tests that assert non-git behavior. (When CLI output changes, keep the frozen-seam CLI tests in sync.)
- **Before tagging a release**, run the full release gate — use the `/preflight` skill (`check_release_ready` + doc-coherence + release-consistency + examples) and confirm the platform matrix (`docs/RELEASE_CHECKLIST.md`).
- Platform parity matters: behavior is gated on both POSIX and Windows (CRLF, drive paths, symlinks, exec bits).
