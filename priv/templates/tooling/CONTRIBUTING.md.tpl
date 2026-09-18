# Development

## Get started

Install **mise** and **PostgreSQL 18**, then prepare and start the application:

```sh
mise trust
mise install
mise run setup
mise run dev
```

Open **http://localhost:4000**. `mise run setup` explicitly creates, migrates and
seeds the development database, then builds assets.

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
Production uses `DATABASE_URL` and `SECRET_KEY_BASE`; see the release section below.

## Command reference

| Command | Purpose |
| --- | --- |
| `mise run check` | Workflow audit, compilation, format check, Credo, xref, Sobelow, assets, tests |
| `mise run test` | Tests with their test-database setup |
| `mise run format` | Explicit formatting |
| `mise run credo` | Compile then strict Credo |
| `mise run audit` | Dependency advisories and retired Hex packages |
| `mise run migrate` | Explicit development migrations |
| `mise run debugserver` | IEx Phoenix server |

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

## Locales and translations

Generated projects resolve the language from `Accept-Language` on every HTTP
request, falling back to `en`. Supported defaults are `en` and `de`. There is no
stored account preference. A changed browser language takes effect on the next
HTTP request/full page load; an already connected LiveView keeps its current
language until then. The session only transports the latest HTTP choice to
LiveView and never overrides a new request header.

Header parsing follows the first supported base language in tag order, as in
Chapisho; q-value weighting is not implemented. Configure `:locales` on the
application and `:default_locale` on its Gettext backend. New `live_session`
blocks should include the application's `{Locale, :set}` hook after account loading.
`Locale.accept_locale/1` also works before a session has been fetched.

With Ithibati, all auth/member screens, ceremony errors, clipboard messages and
validation errors have English/German support. English is the source language;
German catalogs live under `priv/gettext/de/LC_MESSAGES`. Use
`mix gettext.extract --merge` after adding `gettext` calls, then fill in the PO
translations. Clipboard messages are translated on the server, not duplicated in JS.

## Health, releases and migrations

`GET /health` is a public liveness endpoint returning `{"status":"ok"}`. It does
not query the database, set cookies, expose configuration or require authentication.
It proves the HTTP application can answer, not that every dependency is ready.

Build with the project's pinned Elixir/OTP versions on a system compatible with
the deployment target:

```sh
MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix release
```

The release is in `_build/prod/rel/__APP__`. Set `DATABASE_URL`, `SECRET_KEY_BASE`,
`PHX_HOST` and `PORT` for the deployment. Run migration once as an explicit deploy
step, then start the application with `PHX_SERVER=true`:

```sh
bin/__APP__ eval '__MODULE__.Release.migrate()'
PHX_SERVER=true bin/__APP__ start
```

The migration command starts the repo without the HTTP server. It is safe to run
again when all migrations are already applied. It does not create the database.
Provide a database and take backups through your deployment's normal workflow.
The application does not migrate automatically during boot.

For an explicitly reviewed rollback, replace the example version below with the
oldest migration version to undo (the boundary version is also rolled back):

```sh
bin/__APP__ eval '__MODULE__.Release.rollback(__MODULE__.Repo, 20260918000000)'
```

No deployment service, container image or job scheduler is imposed by the starter.
