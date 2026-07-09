# Submodule workflow

For a repository that already contains a valid `.gitmodules` file and gitlink entries:

```sh
version clone --recursive ../superproject superproject
cd superproject
version submodule init
version submodule update --recursive
version submodule status
```

Creating complex submodule fixtures is left to tests because `.gitmodules`, gitlinks, and nested repositories must stay internally consistent.
