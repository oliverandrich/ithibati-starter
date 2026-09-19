# Ithibati New

The dependency-free Mix archive for [Ithibati Starter](../README.md).
It provides `mix ithibati.new my_app [--with-mail]`, automatically selecting Phoenix
and the starter. It does not belong to the Ithibati authentication package.

From this directory, build and install locally:

```sh
mix archive.build
mix archive.install ithibati_new-0.1.0.ez
```

Install the `phx_new` 1.8.14 and `igniter_new` 0.5.34 archives first.
Run `mix help ithibati.new` for options. Use `--starter` to select a local checkout
or pin the generated application's starter version.

All development checks run from the repository root with `mise run check`;
see [CONTRIBUTING.md](../CONTRIBUTING.md). This archive is MIT licensed like the
rest of the repository.
