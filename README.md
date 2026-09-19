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
[Profiles](#choose-your-profile) · [Contributing](CONTRIBUTING.md)

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
  generated `CONTRIBUTING.md`.
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
`CONTRIBUTING.md` covers database variables, browser setup, checks and deployment.
`mise run setup` explicitly creates and migrates the development database; the
installer itself does not.

The archive lives in this repository under `installer/`; it is separate from the
Ithibati authentication package. `mix ithibati.new` automatically selects Phoenix
and installs the starter as a development-only dependency. Installation prompts,
including Igniter's large-diff preview prompt, are accepted automatically. Pass
`--no-yes` to restore interactive confirmation.

The default starter source follows `main`. For reproducible generation, use
`--starter ithibati_starter@github:oliverandrich/ithibati-starter@COMMIT_SHA`.
Installation does not require a Hex release.

<details>
<summary>Use Igniter directly</summary>

After installing the generators above:

```sh
mix igniter.new my_app \
  --with phx.new \
  --with-args="--no-mailer" \
  --install ithibati_starter@github:oliverandrich/ithibati-starter@main \
  --only dev
```

Then enter `my_app` and run the mise setup steps above.

</details>

<details>
<summary>Install from a local starter checkout</summary>

Build the archive from the checkout's `installer/` directory:

```sh
mix archive.build
mix archive.install ithibati_new-0.1.0.ez
```

Then, from the directory where the new project should live:

```sh
mix ithibati.new my_app \
  --starter ithibati_starter@path:/absolute/path/to/ithibati-starter
```

Add `--with-mail` for email invitations.

</details>

## Choose your profile

Ithibati is always included. Choose whether invitations should also be delivered by email:

| Feature | Default | `--with-mail` |
| --- | :---: | :---: |
| Phoenix tooling, checks and CI | ✓ | ✓ |
| Vanilla Tailwind, Lucide and browser locale detection | ✓ | ✓ |
| Username accounts, passkeys and account security | ✓ | ✓ |
| Manual invitation links | ✓ | ✓ |
| Email invitation form and German/English emails | — | ✓ |
| Swoosh, local mailbox preview and SMTP configuration | — | ✓ |
| Healthcheck, release helpers and auth cleanup | ✓ | ✓ |
| Local Beans configuration | Optional | Optional |

Enable invitation mail when creating a project:

```sh
mix ithibati.new my_app --with-mail
```

Or use Igniter directly; the starter adopts and configures the Phoenix mailer:

```sh
mix igniter.new my_app \
  --with phx.new \
  --install ithibati_starter@github:oliverandrich/ithibati-starter@main \
  --only dev --with-mail
```

An app originally generated with `--no-mailer` is also supported: `--with-mail`
creates the missing mailer.

Add **`--without-beans`** to either profile to omit local tracking. Beans itself is
installed separately and is not needed to compile, test or run the app. Neither RTK
nor personal AI skills are required by generated applications.

## Usernames, email and mail delivery

**This starter defaults to usernames, invitation-only registration and manually
shared invitation links.** That is the starter's chosen policy, not a restriction
of Ithibati.

Ithibati lets an application choose its identifier, including an email address.
Since 0.4.0 it also provides optional invitation-mail delivery through
`Ithibati.InvitationMail`, using application-owned content and mailer callbacks.
See the upstream [email-registration example](https://github.com/oliverandrich/ithibati/tree/v0.4.0/examples/email_registration)
for an email-address identifier, emailed registration links and a development
mailbox preview. Authentication still uses passkeys, with recovery codes as fallback.

These are separate choices: delivering an invitation by email does not require
using email as the account identifier, and choosing an email identifier does not
itself enable delivery or verify mailbox ownership. The application's registration
policy decides who may request an invitation.

**`--with-mail` keeps username accounts.** It adds a separate recipient address to
the invitation form, without storing it on the account. The manual-link form remains
available. Email content follows the inviter's browser language (English/German).

Development messages appear at **`/dev/mailbox`** and tests use the Swoosh test
adapter; neither sends external mail. Production uses authenticated SMTP with
STARTTLS and certificate verification. Configure `MAIL_FROM`, `SMTP_HOST`,
`SMTP_USERNAME`, `SMTP_PASSWORD` and optionally `SMTP_PORT` (default `587`), plus
`PHX_HOST` for trusted invitation URLs. The generated `CONTRIBUTING.md` documents
configuration and delivery limits. Other providers can replace the Swoosh adapter.

Delivery is synchronous, limited to 10 attempts per member and 3 per recipient per
hour per node. There are no automatic retries or background jobs. Transport errors
leave the invitation valid and show an error; transport acceptance is not proof of
receipt. Email-as-identifier remains an application-level customization.

## Generated pages

| Route | Purpose |
| --- | --- |
| `/` | Protected home with invitation creation |
| `/setup` | First-account setup; closes after the instance is claimed |
| `/login` | Passkey sign-in |
| `/recover` | Recovery-code sign-in |
| `/invite/:token` | Accept an invitation with a passkey |
| `/recovery-codes` | One-time code display and copying |
| `/account/passkeys` | Passkey management and sign out on all devices |
| `/account/recovery-codes` | Remaining code count and confirmed regeneration |
| `/account/verify` | Identity confirmation for sensitive changes |
| `/health` | Liveness probe |
| `/dev/mailbox` | Development mail preview, only with `--with-mail` |

Customize `Layouts.auth/1` and `Layouts.member/1` to change the shared appearance.
Auth components use the project's module name as their wordmark.

## Deliberate defaults

**A starting point, not an admin product.** Every authenticated member can invite
someone. There are no administrator roles, invitation-management dashboard, billing,
teams or background-job framework. Add the policies your app needs.

**Fresh applications only.** The tested scaffold is a non-umbrella Phoenix 1.8.14
application with PostgreSQL, HTML, LiveView, Tailwind and esbuild. Authentication uses
integer account IDs; `--binary-id` is rejected. Reapplying the same starter
version/profile is a no-op that preserves edits. Switching profiles is refused.
This is not an upgrade manager for generated apps.

**The browser chooses the language.** Each request resolves the first supported
base language in `Accept-Language`, with English as fallback. The session only
passes that choice to LiveView. Connected views keep their language until the next
full load. There is no account preference or language switch; q-value weighting is
not implemented. Add translations through Gettext in the generated app.

**Deployment remains yours.** Claim the first account privately before exposing a
new instance. Rate limits are in-memory and per node; restarts reset them. Configure
trusted proxies or edge limits for your deployment, especially with multiple nodes.
The healthcheck proves HTTP liveness, not database readiness. Migrations and cleanup
never run automatically during application boot.

## Contributing

See **[CONTRIBUTING.md](CONTRIBUTING.md)** for a copyable setup, command reference,
real-project integration checks and the contribution workflow.

## License

**[MIT](https://github.com/oliverandrich/ithibati-starter/blob/main/LICENSE)** — including the starter's application templates.
Adapted Ithibati and Phoenix sources retain their upstream notices in
[NOTICE](https://github.com/oliverandrich/ithibati-starter/blob/main/NOTICE) and [THIRD_PARTY_LICENSES.md](https://github.com/oliverandrich/ithibati-starter/blob/main/THIRD_PARTY_LICENSES.md).
Dependencies retain their respective licenses.
