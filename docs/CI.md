# CI platform confirmation

The release test suite contains platform-policy tests that must be confirmed on real hosts, not only by simulation-level unit tests.

Required release CI matrix:

* POSIX host: Linux runner with symlink support, POSIX execute bits, permission-denied directory semantics, `git`, `tar`, Alire, GNAT, and `gprbuild`.
* Windows host: native Windows runner with drive-path, drive-relative path, UNC-like path, reserved device-name, backslash traversal, CRLF, and Windows hook-discovery behavior.

The matrix must run from a clean checkout with no generated artifacts committed.

## POSIX gate

Run:

```sh
tools/bin/check_platform_ci_matrix posix
```

This gate builds the project, builds and executes the full AUnit suite, runs the release consistency, ref-write-policy, and ref-transaction checks, runs their POSIX self-tests, and requires the POSIX platform-sensitive tests to execute on a real POSIX filesystem.

## Windows gate

Run from PowerShell:

```powershell
tools/bin/check_platform_ci_matrix windows
```

This gate builds the project, builds and executes the full AUnit suite, runs the release consistency, ref-write-policy, and ref-transaction checks available on Windows, and requires the Windows path-policy and hook-discovery tests to execute on a real Windows filesystem.

## Workflow template

`ci/github-actions-platform-matrix.yml` is a copy-ready workflow template for hosted CI. The release package intentionally does not include `.github/` metadata; projects that publish through GitHub should copy this file to `.github/workflows/platform-matrix.yml` before tagging.

The release is not platform-confirmed until both the POSIX and Windows jobs have passed for the exact source tree being released, and their evidence files have been verified with:

```sh
tools/bin/check_platform_ci_evidence .release/platform-ci-evidence
```

The POSIX and Windows gates write `platform-posix.txt` and `platform-windows.txt` when `VERSION_PLATFORM_CI_EVIDENCE_DIR` is set. The evidence checker verifies that both gates passed, both ran on real platform filesystems, both built and ran the full AUnit suite, both ran release consistency, ref-write-policy, and ref-transaction checks, and both evidence files identify the same source tree.

## Evidence summary

After both platform gates have produced evidence and `tools/bin/check_platform_ci_evidence` has verified it, generate the release-facing summary with:

```sh
tools/bin/summarize_release_evidence .release/platform-ci-evidence
```

The summary prints the shared source tree identity, POSIX and Windows filesystem modes, build/AUnit/release-consistency results, timestamps, and a final verified status. It is intended for release notes and sign-off logs; it does not replace the evidence validator.
