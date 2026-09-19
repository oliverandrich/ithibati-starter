# Contributing

## Get started

Install **mise** and **PostgreSQL 18**, then prepare and start the application:

```sh
mise trust
mise install
mise run setup
mise run setup-code
mise run dev
```

Open **http://localhost:4000**. `mise run setup` explicitly creates, migrates and
seeds the development database, then builds assets. Enter the printed setup code
to claim the first account.

## Configure the database

Local defaults are `localhost:5432`, user `postgres`, password `postgres`.
Override them through the environment when needed:

```sh
export PGHOST=127.0.0.1
export PGPORT=5432
export PGUSER=postgres
export PGPASSWORD=postgres
```

Tests use a separate `__APP___test` database, optionally suffixed with
`MIX_TEST_PARTITION`. Never point tests at development or production data.
Production uses `DATABASE_URL` and `SECRET_KEY_BASE`; see [Operations](docs/operations.md).

## Command reference

| Command | Purpose |
| --- | --- |
| `mise run check` | Workflow audit, compilation, format check, Credo, xref, Sobelow, assets, tests |
| `mise run test` | Tests with their test-database setup |
| `mise run format` | Explicit formatting |
| `mise run credo` | Compile then strict Credo |
| `mise run audit` | Dependency advisories and retired Hex packages |
| `mise run migrate` | Explicit development migrations |
| `mise run setup-code` | Issue or replace the first-account setup code |
| `mise run dev` | Start the development server in the foreground |
| `mise run reset` | Drop and recreate the development database, migrate and seed |
| `mise run debugserver` | IEx Phoenix server |
| `mise run release` | Build a production release for the current OS and architecture |

Keep migration history unchanged. Credo scans source, tests and all migrations;
Jump inspects inline HEEx and files reached through embed_templates. ExSlop and
Jump rules are explicitly selected. Audit findings are separate from PR gates.
Tidewave runs only in development on loopback at /tidewave/mcp.
Tailwind/esbuild are Mix-managed; Node is unnecessary.
Use Lucide components directly, for example `<Lucideicons.chevron_down class="size-4" aria-hidden="true" />`.
Decorative icons are hidden from assistive technology; label icon-only buttons.
The `lucide_icons` dependency supplies SVG components without a Tailwind icon plugin. The UI helpers use the CSP's inline-script/style allowances.

Read AGENTS.md for TDD and commit review rules. Generated code belongs to this
application. Re-running the same starter/profile does nothing; it does not upgrade
or overwrite your edits. Review dependency updates through normal PRs.

`mise dev`, `mise reset`, `mise migrate`, `mise setup-code` and `mise release` are the short forms
of `mise run …`. Development tasks explicitly use `MIX_ENV=dev`; release builds
use `prod`. `mise reset` deletes the development database and runs its migrations
and seeds again. It is an explicit local action, never part of startup or checks.

## Browser tests

Browser tests are mandatory: install Chrome and a matching Chromedriver. On CI,
CHROMEWEBDRIVER points at the runner's driver directory. Locally configure a matching
`chromedriver` in ignored `mise.local.toml`, or set CHROMEWEBDRIVER. Check both
versions after browser updates. `mise run check` builds assets before browser tests;
for direct `mise run test`, build them with `mix assets.build` first. Tests start
an endpoint on port 4102; override PORT to isolate concurrent suites. Missing browser
infrastructure fails instead of silently skipping coverage.

`mix ithibati.doctor` is part of the test-environment gate after schema setup.

## Translations

With Ithibati, all auth/member screens, ceremony errors, clipboard messages and
validation errors have English/German support. English is the source language;
German catalogs live under `priv/gettext/de/LC_MESSAGES`. Use
`mix gettext.extract --merge` after adding `gettext` calls, then fill in the PO
translations. Clipboard messages are translated on the server, not duplicated in JS.

## Making changes

Use focused regression tests for behavior changes and run `mise check` before
submitting. Follow the TDD and Conventional Commit rules in [AGENTS.md](AGENTS.md).

## Further reading

- [Operations](docs/operations.md): configuration, releases and migrations.
- [Authentication](docs/authentication.md): accounts, invitations and security.
- [Localization](docs/localization.md): language selection and translations.
