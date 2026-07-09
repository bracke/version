# Security

`version` is not a sandbox. It parses and mutates attacker-controlled repository data when run on untrusted repositories.

Path safety is centralized in `Version.Path_Safety`; working-tree materialization and deletion plans should route through `Version.Filesystem_Guard`. Ref names are checked through `Version.Ref_Names`, including Windows-safe component restrictions. Repository format metadata is validated before higher-level operations proceed.

Checkout, restore, branch switch, clone checkout, sparse mutation, stash restoration, remove, and submodule materialization are designed to fail before mutation when a target path is unsafe.

Client-side hooks are executable code from the repository. Supported hooks are allow-listed (`pre-commit`, `commit-msg`, `pre-merge-commit`, `post-commit`, `post-merge`, `post-checkout`, `pre-push`) and invoked with direct process arguments rather than shell interpolation. `--no-verify` is available on supported save/push paths.

HTTP(S) trust depends on the configured HTTP/TLS backend and certificate store. SSH trust depends on the SSH client, host-key policy, key selection, and agent configuration. `version` must not silently downgrade transport security.

Known limits: full parser hardening against malicious repositories is ongoing, credential-helper UX is limited, hook timeout/full environment parity is not claimed, full host-specific Unicode normalization collision handling beyond common UTF-8 Latin accent preflight is deferred, partial-clone lazy fetch trusts the configured promisor transport, and LFS support is limited to attribute-gated clean pointer generation during staging plus merge smudge from local media, configured local/file LFS stores, HTTP(S) Git LFS batch download endpoints, or SSH `git-lfs-authenticate` followed by the advertised HTTP(S) batch endpoint; broader Git LFS command parity is not claimed.
