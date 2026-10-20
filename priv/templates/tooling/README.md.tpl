# __MODULE__

Created with Ithibati Starter __STARTER_VERSION__: Phoenix, LiveView, SQLite or PostgreSQL and opinionated tooling.

```sh
mise trust
mise install
mise run setup
mise run setup-code
mise dev
```

Enter the printed code at `/setup` to create the first account. Generate a replacement
code with the same command if needed; only the latest code works.

SQLite is the default database, in `tmp/__APP___dev.db` during development. Set
`__APP_UPCASE___DATABASE=postgres` to use PostgreSQL instead. A release needs
`DATABASE_PATH` or `DATABASE_URL`; see [Operations](docs/operations.md#choosing-a-database).

Use `mise reset` to explicitly recreate the development database (deletes its data),
`mise migrate` for pending development migrations, and `mise release` to build the
production package. In that package, run `bin/setup-code`, then `bin/server`. Both
migrate the database first, as described in [Operations](docs/operations.md).

## Documentation

- [Contributing](CONTRIBUTING.md): development setup, mise commands and tests.
- [Operations](docs/operations.md): configuration, releases and migrations.
- [Authentication](docs/authentication.md): accounts, invitations and security.
- [Localization](docs/localization.md): language selection and translations.
- [Interface](docs/interface.md): layouts, page shapes and navigation.
