# CI templates

This directory contains source-controlled CI templates. Release packages exclude `.github/` metadata, so the GitHub Actions template is kept here and may be copied into `.github/workflows/` by projects that use GitHub-hosted CI.

Required release platform confirmation:

* POSIX: `tools/bin/check_platform_ci_matrix posix`
* Windows: `tools/bin/check_platform_ci_matrix windows`
