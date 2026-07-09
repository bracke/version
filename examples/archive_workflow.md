# Archive workflow

Create source archives from committed repository objects without checking out a
new working tree.

```sh
version archive HEAD --output source.tar
version archive HEAD --format zip
version archive v1.0 --output release.zip
version archive main src/ docs/
```

Archives are generated from the selected revision tree. Dirty working-tree
changes, staged-but-uncommitted changes, sparse checkout materialization, and
submodule working directories are not read.

TAR output is uncompressed and preserves executable mode metadata. ZIP output
uses the integrated Ada Zlib stored-deflate path and preserves exact committed
blob bytes, including binary data.

## Prefix a release archive

```sh
version archive HEAD --format zip --output release.zip --prefix version-1.0/
```

The prefix is applied to archive entry names after pathspec matching, giving extractors a stable top-level directory without changing repository paths.
