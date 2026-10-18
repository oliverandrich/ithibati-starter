# Ithibati New

The dependency-free Mix archive for [Ithibati Starter](https://github.com/oliverandrich/ithibati-starter).
It provides `mix ithibati.new my_app`, automatically selecting Phoenix
and the starter. It does not belong to the Ithibati authentication package.

From this directory, build and install locally:

```sh
mix archive.build
mix archive.install ithibati_new-0.9.0.ez
```

Install the `phx_new` 1.8.14 and `igniter_new` 0.5.34 archives first.
Archive version 0.9.0 installs `ithibati_starter` 0.9.0 from Hex by default. Run
`mix help ithibati.new` for options. Use `--starter` to select a local checkout,
another version or a Git revision. The generated `mix.lock` records what it resolved.

All development checks run from the repository root with `mise run check`; see
[CONTRIBUTING.md](https://github.com/oliverandrich/ithibati-starter/blob/main/CONTRIBUTING.md).
This archive is MIT licensed like the rest of the repository; see `LICENSE`.
