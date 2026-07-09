---
name: preflight
description: Run the release-readiness gate for this project — full preflight plus doc-coherence, release-consistency, and examples checks. Use before tagging a release or when asked to verify release readiness.
---

Run the release gate and report a pass/fail summary. These checks guard release-critical behavior (CLI output, exit codes, compatibility, transport, archive, hooks, portability — see `docs/COMPATIBILITY.md`).

1. Ensure the tools are built (the `tools/bin/*` binaries are produced from `tools/tools.gpr`):
   ```
   alr exec -- gprbuild -P tools/tools.gpr
   ```

2. Run the full preflight (this is the umbrella check):
   ```
   tools/bin/check_release_ready
   ```

3. Run the focused gates (run these too — `check_release_ready` may not cover all of them depending on configuration):
   ```
   tools/bin/check_documentation_coherence
   tools/bin/check_release_consistency
   tools/bin/check_examples
   ```

4. Report a per-check pass/fail summary. For any failure, surface the specific diagnostic lines so the user can act on them. Do not dump full passing output.

Notes:
- Platform-matrix evidence gates (`check_platform_ci_matrix`, `check_platform_ci_evidence`, `summarize_release_evidence`) require CI-produced evidence under `.release/platform-ci-evidence` and the `VERSION_PLATFORM_CI_EVIDENCE_DIR` env var — only run those if that evidence is present locally.
- If a tool binary is missing, build step 1 first; if it still fails, report which `tools/tools.gpr` target failed to build.
