# Ithibati Starter

**Start with a Phoenix app that already feels like your app.**

[![CI](https://github.com/oliverandrich/ithibati-starter/actions/workflows/ci.yml/badge.svg)](https://github.com/oliverandrich/ithibati-starter/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/oliverandrich/ithibati-starter/blob/main/LICENSE)
[![Phoenix 1.8](https://img.shields.io/badge/Phoenix-1.8-orange.svg)](https://phoenixframework.org)
[![Ithibati 0.4.0](https://img.shields.io/badge/Ithibati-0.4.0-violet.svg)](https://github.com/oliverandrich/ithibati)

An opinionated [Igniter](https://github.com/ash-project/igniter) installer for fresh
Phoenix applications: passkeys, invitation-only accounts, vanilla Tailwind,
English/German screens, and a development workflow you can keep using.

The installer writes ordinary application code. You own it, customize it, and run
it without the starter as a runtime dependency.

[Get started](#get-started) · [What's included](#whats-included) ·
[Profiles](docs/usage.md#choose-your-profile) · [Contributing](CONTRIBUTING.md)

## What's included

### Authentication and account security

Powered by **Ithibati 0.4.0**, with username-based accounts and passkeys:

- **Claim the site:** the first visitor creates the first account; subsequent
  registrations require an invitation.
- **Invitations:** signed-in members can create personal, expiring, single-use
  links for a chosen username.
- **Separate sign-in and recovery screens:** use a passkey, or a recovery code
  when your passkey is unavailable.
- **Passkey settings:** add, rename and remove your own passkeys. The last one
  cannot be removed.
- **Recovery-code settings:** see the remaining count and replace the old batch
  after confirmation. New codes are shown once with a copy button.
- **Fresh identity confirmation:** adding a passkey or generating new recovery
  codes requires confirmation with the current account's passkey or recovery code,
  valid for five minutes.
- **Revocable sessions:** sign out here or on every device, including connected
  LiveViews. Session cookies are encrypted.
- **Auth rate limits:** 10 recovery requests and 120 other ceremony requests per
  peer IP per minute, per running instance, with HTTP 429 and `Retry-After`.
- **Request protection:** CSRF checks, a baseline Content Security Policy and
  request-log filtering for tokens, recovery codes and WebAuthn credentials.

### A small, finished interface

- **Vanilla Tailwind CSS 4** and **[Lucide SVG components](https://github.com/zoedsoupe/lucide_icons)**.
  No DaisyUI or Heroicons plugin.
- Centered auth screens with the project name, a violet accent and responsive layouts.
- A protected home page, project name on the left and username menu on the right.
- Light/dark styling follows the operating system, without a theme switch or stored override.
- **English and German** auth screens, validation messages and ceremony feedback.
  The browser determines the language on each HTTP request.
- Keyboard-friendly native controls, visible focus states and clipboard fallback.

### Development tooling

| Included | What it does |
| --- | --- |
| mise | Pins Elixir, Erlang/OTP and workflow-audit tooling; provides setup, dev and check tasks |
| Credo | Strict checks, with selected ExSlop, Jump and migration checks |
| Sobelow | Security analysis in the application check gate |
| ExUnit + Wallaby | Application tests and real browser/WebAuthn flows using virtual authenticators |
| Tidewave | Development-only Phoenix integration |
| GitHub Actions | Check workflows plus a separate dependency-audit workflow |
| Dependabot | Grouped dependency and Actions updates |
| Beans, optional | Local, Git-ignored work tracking |

`mise run check` compiles, checks formatting and unused locks, runs Credo and xref,
scans with Sobelow, builds assets and runs tests. It also checks the Ithibati setup.
Dependency advisories run separately through `mise run audit`.

### Operations, without choosing your hosting

- **`GET /health`**: public, session-free liveness endpoint returning `{"status":"ok"}`.
- **Release helpers**: explicit migration and rollback commands, documented in the
  generated `docs/operations.md`.
- **Auth cleanup**: `mix auth.cleanup` or `MyApp.AuthCleanup.run/0` removes expired
  sessions, abandoned challenges and expired, unaccepted invitations.
- Environment-based database configuration and a documented release workflow.

Cleanup is explicit. Choose Oban, cron or your hosting platform in the application
when you need scheduling; the starter installs no scheduler.

## Get started

You'll need **mise**, **Elixir 1.20.4 / OTP 29.0.6** and **PostgreSQL 18**.
Chrome and a matching Chromedriver are required for the browser tests.
Node.js is not required: Mix manages Tailwind and esbuild.

Install the pinned generators and the starter archive once:

```sh
mix archive.install hex phx_new 1.8.14
mix archive.install hex igniter_new 0.5.34
mix archive.install github oliverandrich/ithibati-starter --sparse installer
```

Create a Phoenix app with the starter:

```sh
mix ithibati.new my_app
cd my_app
```

Start developing:

```sh
mise trust
mise install
mise run setup
mise run dev
```

Open **http://localhost:4000** and claim your instance. The generated
`CONTRIBUTING.md` covers development and checks; `docs/operations.md` covers deployment.
`mise run setup` explicitly creates and migrates the development database; the
installer itself does not.

## Documentation

[Usage guide](docs/usage.md) covers generator options, profiles, mail, generated
pages and defaults. Generated applications include `CONTRIBUTING.md`, `AGENTS.md`
and application guides under `docs/`.

## Contributing

See **[CONTRIBUTING.md](CONTRIBUTING.md)** for a copyable setup, command reference,
real-project integration checks and the contribution workflow.

## License

**[MIT](https://github.com/oliverandrich/ithibati-starter/blob/main/LICENSE)** — including the starter's application templates.
Adapted Ithibati and Phoenix sources retain their upstream notices in
[NOTICE](https://github.com/oliverandrich/ithibati-starter/blob/main/NOTICE) and [THIRD_PARTY_LICENSES.md](https://github.com/oliverandrich/ithibati-starter/blob/main/THIRD_PARTY_LICENSES.md).
Dependencies retain their respective licenses.
