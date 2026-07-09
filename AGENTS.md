# Agent instructions

This crate enforces GNAT 15 through Alire with `gnat_native = "=15.2.1"` in
every active manifest. Do not run plain system GNAT, GPRBuild, GNATprove,
GNATdoc, or related `gnat*` tools from `PATH`.

Use Alire-selected tools:

```sh
alr exec -- gnatls --version
alr build
cd tests && alr exec -- gprbuild -P tests.gpr
alr exec -- gprbuild -P tools/tools.gpr
```

The compiler version command must report `GNATLS 15.x`.

See `CLAUDE.md` for the full repository guidance.
