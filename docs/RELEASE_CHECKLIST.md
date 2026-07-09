# Release checklist

Run from a clean checkout. Normal release verification must not depend on public internet access.

## Build and tests

```sh
alr build
alr exec -- gprbuild -P tests/tests.gpr
./tests/bin/tests
(cd ../versionlib/tests && alr exec -- gprbuild -P versionlib_tests.gpr && ./bin/tests)
alr exec -- gprbuild -P tools/tools.gpr
tools/bin/check_release_ready
tools/bin/check_version_metadata
tools/bin/check_release_manifests
tools/bin/check_release_consistency
tools/bin/check_release_package_selftest
tools/bin/check_documentation_coherence
tools/bin/check_examples
git --version
```

If a platform cannot run the shell smoke tool, manually execute the commands in `examples/basic_workflow.md`, `examples/local_remote_workflow.md`, and `examples/worktree_workflow.md` inside a temporary directory.


## Required release smoke workflows

Each 1.0 release candidate must execute the following workflows from a clean checkout or from an installed `version` binary on `PATH`. These workflows are release-critical because they exercise the compatibility and lifecycle promises documented in `docs/COMPATIBILITY.md`.

```text
init -> stage -> save -> git fsck
clone local -> branch switch -> status clean
fetch/push local round trip
archive tar export
archive zip export
restore/checkout path workflows
rebase conflict workflow
cherry-pick conflict workflow
revert conflict workflow
worktree add/remove
submodule update
```

Normal release verification must use local repositories and fixtures only. HTTP(S) and SSH checks may use local/private fixtures where available, but the normal checklist must not depend on the public internet.

## Documentation review

Confirm README status/version, `docs/COMMANDS.md` command grammar, `docs/COMPATIBILITY.md` compatibility decisions, honest compatibility limits, no public-internet release-test dependency, and current security/portability/worktree/submodule/hook caveats.

## Smoke test

```sh
rm -rf /tmp/version-release-smoke
mkdir -p /tmp/version-release-smoke
cd /tmp/version-release-smoke
version init v
cd v
printf 'hello\n' > a.txt
version stage a.txt
version save "initial"
version verify
git fsck --strict
git log --oneline
version status
```

## Compatibility spot check

```sh
rm -rf /tmp/version-git-roundtrip
mkdir -p /tmp/version-git-roundtrip
cd /tmp/version-git-roundtrip
git init repo
cd repo
git config user.email test@example.com
git config user.name Test
printf 'from git\n' > a.txt
git add a.txt
version save "version save in git repo"
version verify
git fsck --strict
git status --porcelain
```

## Publishing (two crates)

`version` (the CLI) depends on the separately published `versionlib` library crate. Release them in order:

1. **Publish `versionlib` first.** From `../versionlib`, ensure its own dependencies (`httpclient`, `zlib`, `i18n`, `ssh_lib`) are published/resolvable from the registry rather than local path pins, then publish it. Its package must include `src/`, `tests/`, `alire.toml`, project files, `README.md`, `LICENSE`, and `LICENSES/` and exclude build outputs.
2. **Then publish `version`.** Its `alire.toml` depends on `versionlib = "~0.1.0-dev"`; the `[[pins]]` entry pointing at `../versionlib` is a **local-development override only** and must not appear in the published manifest (`alr publish` resolves the registry dependency instead). The `version` source package therefore does **not** bundle `versionlib`.

Keep the two crate versions in lockstep until they are released, and bump the `versionlib` dependency constraint in `version/alire.toml` whenever `versionlib`'s published version changes.

Run `tools/bin/stage_release` to generate the pin-free publishable manifests under `.release/staged/<crate>/alire.toml` (dev manifests are left untouched) and validate them; `tools/bin/check_release_manifests` validates that the dev manifests keep the intentional local pins.

## Package contents

These contents apply to each crate's own source package. Exclude build outputs, `.git/`, scratch repositories, coverage, archives, locks, `*.o`, and `*.ali`. Include `src/`, `tests/`, `docs/` (where present), `examples/`, `tools/`, `alire.toml`, project files, README, CHANGELOG, LICENSE, and `LICENSES/`. The `version` package does not include `versionlib` sources — it is a registry dependency.

Run:

```sh
tools/bin/check_release_package version-0.1.0-dev.tar.gz
tools/bin/check_release_package version-0.1.0-dev.zip
tools/bin/check_release_ready
tools/bin/check_version_metadata
tools/bin/check_release_manifests
tools/bin/check_release_consistency
tools/bin/check_test_scope_completeness
tools/bin/check_ref_write_policy
tools/bin/check_ref_write_policy_selftest
tools/bin/check_ref_transaction_selftest
# Review docs/REF_TRANSACTION.md when changing expected-old ref mutation behavior.
tools/bin/check_platform_ci_evidence_selftest
tools/bin/check_release_package_selftest
tools/bin/check_documentation_coherence
version --version
```

The printed version must match `Version.Version_String`, `alire.toml`, README, CHANGELOG, and release notes.

- Run `tools/bin/check_release_ready` from a built tools project for the full local release preflight.
- Run `tools/bin/check_release_consistency_selftest` when changing release consistency rules so drift detection itself is covered.
- Run `tools/bin/check_test_scope_completeness` before release so the Phase 43 test-scope closure suites and gates remain registered.
- Run `tools/bin/check_release_package_selftest` when changing release package-shape rules so missing files and forbidden artifacts remain covered.
- Run `tools/bin/check_documentation_coherence` when changing release documentation, diagnostics, or release-gate lists so stale wording and malformed release notes are caught.


## Platform CI confirmation

Before tagging, run or verify the hosted CI matrix for the exact source tree:

```sh
tools/bin/check_platform_ci_matrix posix
```

On Windows PowerShell:

```powershell
tools/bin/check_platform_ci_matrix windows
```

Both gates must pass. The POSIX job confirms symlink, executable-bit, permission-denied, archive, and Git compatibility behavior on a real POSIX filesystem. The Windows job confirms drive-path, drive-relative path, UNC-like path, reserved device-name, backslash traversal, CRLF, and Windows hook-discovery behavior on a real Windows filesystem.

For release evidence, run the gates with `VERSION_PLATFORM_CI_EVIDENCE_DIR=.release/platform-ci-evidence` or download the workflow artifacts produced by `ci/github-actions-platform-matrix.yml`, then verify them:

```sh
tools/bin/check_platform_ci_evidence .release/platform-ci-evidence
tools/bin/summarize_release_evidence .release/platform-ci-evidence
```

The evidence files must name the same source tree as the release candidate and must contain `result=passed`, `build=passed`, `aunit=passed`, `release_consistency=passed`, `ref_write_policy=passed`, and `ref_transaction=passed` for both POSIX and Windows.
- Run `version doctor --release` from the source checkout as a convenience preflight before packaging. This does not replace the explicit release/package/platform evidence gates listed above.
