# Contributing

## Setup

```sh
mise trust && mise install
mise run setup
mise run setup-code
mise run dev
```

Open http://localhost:4000 and enter the printed code. `mise run check` also needs
PostgreSQL 18.

## Databases

Development uses SQLite in `tmp/__APP___dev.db`. `__APP_UPCASE___DATABASE=postgres` switches
to PostgreSQL, which reads `PGHOST`, `PGPORT`, `PGUSER` and `PGPASSWORD`. Tests use
`__APP___test`, suffixed with `MIX_TEST_PARTITION` when set. [Operations](docs/operations.md)
covers production.

## Commands

| Command | Does |
| --- | --- |
| `mise run check` | gitleaks, compile, format, Credo, xref, Sobelow, assets, tests on SQLite and PostgreSQL |
| `mise run test [PATH]` | Tests on SQLite |
| `mise run test:postgres` | Tests on PostgreSQL, without browser features |
| `mise run format` | Format the source |
| `mise run audit` | Dependency advisories |
| `mise run dev` | Development server |
| `mise run debugserver` | Development server in IEx |
| `mise run migrate` | Development migrations |
| `mise run setup-code` | Issue or replace the setup code |
| `mise run reset` | Drop and recreate the development database |
| `mise run release` | Production release for this platform |

`check` does not format. gitleaks scans every commit and the staged changes. A secret in an
old commit still fails; rotate it. `.gitleaks.toml` holds the allowed exceptions.

## Browser tests

Browser tests run in Playwright's Chrome for Testing; `mise run browser` installs it. They
use port 4102; set `PORT` to change it. Before `mise run test`, build assets with
`mix assets.build`. `PW_SCREENSHOT=true mix test --failed` keeps screenshots in
`screenshots/`.

## Starter drift

`test/__APP__/starter_drift_test.exs` compares generated files with the locked
`ithibati_starter`. After `mix deps.update ithibati_starter`, it names the changed files. Take
the new version, or list the file in `@owned`.
[Upgrading](https://github.com/oliverandrich/ithibati-starter/blob/main/docs/upgrading.md)
describes the full process.

## License markers

Every source file names its license as `SPDX-License-Identifier` in its first five lines.
`test/__APP__/license_marker_test.exs` checks it. Add the line to new files, including those
from `mix phx.gen.*`. Code under `vendor/` keeps its own.

## Icons

Use Lucide components, for example
`<Lucideicons.chevron_down class="size-4" aria-hidden="true" />`. Label icon-only buttons.

## Further reading

- [Operations](docs/operations.md): configuration, releases, migrations.
- [Authentication](docs/authentication.md): accounts, invitations, limits.
- [Localization](docs/localization.md): languages and [translations](docs/localization.md#translations).
- [Interface](docs/interface.md): layouts, navigation, colours and type.
