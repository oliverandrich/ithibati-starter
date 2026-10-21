# Ithibati Starter

[![CI](https://github.com/oliverandrich/ithibati-starter/actions/workflows/ci.yml/badge.svg)](https://github.com/oliverandrich/ithibati-starter/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/oliverandrich/ithibati-starter/blob/main/LICENSE)
[![Ithibati 0.11.0](https://img.shields.io/badge/Ithibati-0.11.0-violet.svg)](https://github.com/oliverandrich/ithibati)

An [Igniter](https://github.com/ash-project/igniter) installer for new Phoenix 1.8 applications.
It adds passkey sign-in with invitations, a finished interface and a check pipeline.
The generated code is yours; the starter is not a runtime dependency.

## What you get

| Area | Included |
| --- | --- |
| Accounts | Passkeys and recovery codes through [Ithibati](https://github.com/oliverandrich/ithibati). An operator code claims the instance; everyone else needs an invitation. |
| Account pages | Settings, passkeys, recovery codes, invitations, an administrator's account list. |
| Interface | A sidebar shell with a phone tab bar, Tailwind 4 colour tokens, Lucide icons, light and dark mode, English and German. |
| Databases | SQLite or PostgreSQL from one build, chosen at runtime. |
| Mail | Swoosh with a development mailbox and SMTP. |
| Checks | `mise run check`: format, Credo, Sobelow, gitleaks, tests on both databases, Playwright browser tests. |
| CI | GitHub Actions, Dependabot, a dependency audit. |
| Operations | Releases that migrate on start, a `Dockerfile`, `/health`, JSON logs, auth cleanup. |
| License | `--license mit` or `agpl`. |

## Get started

You need Elixir 1.20 on OTP 29 for the archives, and [mise](https://mise.jdx.dev) for the
application. PostgreSQL 18 is needed for `mise run check`.

```sh
mix archive.install hex phx_new 1.8.16
mix archive.install hex igniter_new 0.5.35
mix archive.install hex ithibati_new 0.9.0

mix ithibati.new my_app
cd my_app
mise trust && mise install
mise run setup
mise run setup-code
mise run dev
```

Open http://localhost:4000, enter the printed code and register the first account.

## Documentation

- [Usage](docs/usage.md): options, routes, components, colours.
- [Upgrading](docs/upgrading.md): apply a newer starter to a generated application.
- The guides a generated application gets: on [HexDocs](https://hexdocs.pm/ithibati_starter).
- [Changelog](CHANGELOG.md), [Contributing](CONTRIBUTING.md).

## License

[MIT](https://github.com/oliverandrich/ithibati-starter/blob/main/LICENSE).
Generated files belong to your application and need no attribution.
Choose their license with `--license`.
