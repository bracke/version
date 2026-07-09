---
name: run-tests
description: Build and run the AUnit test suites for this Ada project (versionlib functionality + version CLI) and report failures concisely. Use when asked to run the tests, check that tests pass, or verify a change.
---

The project is split into two crates, each with its own AUnit test crate. Build and run both, then report.

1. **Library / functionality suite** (`versionlib`, the bulk of the tests):
   ```
   (cd ../versionlib/tests && alr build) && (cd ../versionlib/tests && ./bin/tests)
   ```

2. **CLI suite** (CLI parsing, hooks, docs, CLI-integration) — must run from the `version/` crate dir so the tests find `bin/main` and `docs/`:
   ```
   alr build && (cd tests && alr build) && ./tests/bin/tests
   ```
   (The `alr build` first ensures `bin/main` is current, which the CLI-integration tests invoke.)

If a build fails, stop and report the GNAT errors — do not run the binary.

3. Report concisely:
   - If all pass, give the total for each suite (e.g. "versionlib 1075/1075, version 114/114").
   - If any fail, list each failing test and its assertion message. Do not dump the full passing output.

Notes:
- Library changes → the versionlib suite is the relevant one; CLI changes → the version suite. Run both before reporting a change done.
- Suites use local fixtures and the system `git` command; no network is required.
