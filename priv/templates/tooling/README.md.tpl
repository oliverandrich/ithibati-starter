# __MODULE__

Created with Ithibati Starter 0.1.0: Phoenix, LiveView, PostgreSQL and opinionated tooling.

```sh
mise trust
mise install
mise run setup
mise dev
```

Use `mise reset` to explicitly recreate the development database (deletes its data),
`mise migrate` for pending development migrations, and `mise release` to build the
production package. In that package, run `bin/migrate` once, then `bin/server`.

See [CONTRIBUTING.md](CONTRIBUTING.md) for configuration and checks.
