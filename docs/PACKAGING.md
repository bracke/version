# Packaging

A release archive should be produced from a clean source tree and should not include build outputs, local repositories, lock leftovers, coverage reports, or temporary archives. Generated install/share directories such as `share/` and `tests/share/` must also be absent.

Required source payload:

```text
src/
tests/
docs/
examples/
tools/
config/
alire.toml
version.gpr
README.md
CHANGELOG.md
LICENSE
LICENSES/
```

Before tagging, run `docs/RELEASE_CHECKLIST.md` and inspect the archive with:

```sh
tar tf version-*.tar.gz | sort
zipinfo -1 version-*.zip | sort
```


Additional release-source checks:

```sh
tools/bin/check_release_ready
tools/bin/check_version_metadata
tools/bin/check_release_consistency
tools/bin/check_test_scope_completeness
tools/bin/check_ref_write_policy
tools/bin/check_ref_write_policy_selftest
tools/bin/check_ref_transaction_selftest
tools/bin/check_platform_ci_evidence_selftest
tools/bin/check_release_package_selftest
tools/bin/check_documentation_coherence
tools/bin/check_release_package version-0.1.0-dev.tar.gz
tools/bin/check_release_package version-0.1.0-dev.zip
```

The source archive must not ship a parent-directory dependency pin in the root `alire.toml`; that would make a standalone release depend on the packager's local checkout layout. Test-crate pins in `tests/alire.toml` are allowed because they intentionally point the test crate back at the checked-out source tree.

`docs/REF_TRANSACTION.md` is a required release document because it records the expected-old ref mutation and rollback contract used by release-critical ref updates.

- Run `tools/bin/check_release_ready` from a built tools project for the full local release preflight.
- Run `tools/bin/check_release_consistency_selftest` when changing release consistency rules so drift detection itself is covered.
- Run `tools/bin/check_test_scope_completeness` when changing release-critical test-suite coverage so missing suites, registration drift, and missing gates are caught.
- Run `tools/bin/check_ref_write_policy` when changing ref update code so production `Atomic_Write_Ref` use remains confined to `Version.Refs`.
- Run `tools/bin/check_ref_write_policy_selftest` when changing the ref write policy guardrail so its positive and negative cases stay covered.
- Run `tools/bin/check_ref_transaction_selftest` when changing ref transaction expected-old behavior so the release-facing contract smoke test stays covered.
- Run `tools/bin/check_release_package_selftest` when changing package-shape rules so negative artifact and missing-file checks stay covered.
- Run `tools/bin/check_documentation_coherence` when changing release-facing documentation or diagnostics so stale wording and malformed release notes are caught.


## Platform CI gates

Release packaging must retain `docs/CI.md`, `ci/github-actions-platform-matrix.yml`, `tools/check_platform_ci_matrix.adb`, `tools/check_platform_ci_evidence.adb`, `tools/check_platform_ci_evidence_selftest.adb`, and `tools/summarize_release_evidence.adb`. The package remains source-clean, so `.github/` workflow metadata is intentionally not required in the release archive; copy the CI template from `ci/` into the hosting provider before release.

Before tagging, collect POSIX and Windows evidence files from the platform gates and run:

```sh
tools/bin/check_platform_ci_evidence .release/platform-ci-evidence
tools/bin/summarize_release_evidence .release/platform-ci-evidence
```

The release package must not include `.release/` evidence artifacts; evidence belongs to the release process, not the source archive.
Before creating a package, `tools/bin/check_release_ready` is the full local release preflight after building `tools/tools.gpr`; `version doctor --release` may also be used as a lighter source-tree convenience preflight. The package is still accepted only by `tools/bin/check_release_package` and the required platform evidence gates.
