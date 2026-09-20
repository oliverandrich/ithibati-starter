# Using Ithibati Starter

## Get started

You'll need **mise**, **Elixir 1.20.4 / OTP 29.0.6** and **PostgreSQL 18**.
Chrome and a matching Chromedriver are required for the browser tests.
Node.js is not required: Mix manages Tailwind and esbuild.

Install the pinned generators and the starter archive once:

```sh
mix archive.install hex phx_new 1.8.14
mix archive.install hex igniter_new 0.5.34
mix archive.install github oliverandrich/ithibati-starter tag v0.2.0 --sparse installer
```

Create a Phoenix app with the starter:

```sh
mix ithibati.new my_app
cd my_app
```

The `ithibati_new` 0.2.0 archive selects Starter tag `v0.2.0` by default. Check
the `ithibati_starter` entry in the generated `mix.lock` to identify the exact
resolved commit. `--starter` accepts another tag, commit or local checkout.

Start developing:

```sh
mise trust
mise install
mise run setup
mise run setup-code
mise run dev
```

Open **http://localhost:4000**, enter the printed code and claim your instance. The generated
`CONTRIBUTING.md` covers development and checks; `docs/operations.md` covers deployment.
`mise run setup` explicitly creates and migrates the development database; the
installer itself does not.

The archive lives in this repository under `installer/`; it is separate from the
Ithibati authentication package. `mix ithibati.new` automatically selects Phoenix
and installs the starter as a development-only dependency. Installation prompts,
including Igniter's large-diff preview prompt, are accepted automatically. Pass
`--no-yes` to restore interactive confirmation.

The archive and Starter use the same release tag. To reproduce a generated
application later, keep the release tag, the Starter commit from `mix.lock`, the
selected profile and your dependency lockfile. Installation does not require a
Hex release.

<details>
<summary>Use Igniter directly</summary>

After installing the generators above:

```sh
mix igniter.new my_app \
  --with phx.new \
  --with-args="--no-mailer" \
  --install ithibati_starter@github:oliverandrich/ithibati-starter@v0.2.0 \
  --only dev
```

Then enter `my_app` and run the mise setup steps above.

</details>

<details>
<summary>Install from a local starter checkout</summary>

Build the archive from the checkout's `installer/` directory:

```sh
mix archive.build
mix archive.install ithibati_new-0.2.0.ez
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
  --install ithibati_starter@github:oliverandrich/ithibati-starter@v0.2.0 \
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
of Ithibati. The manual form allows 10 creation attempts per signed-in account
per hour per node; its limit is separate from optional mail delivery.

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
`PHX_HOST` for trusted invitation URLs. The generated `docs/mail.md` documents
configuration and delivery limits. Other providers can replace the Swoosh adapter.

Delivery is synchronous, limited to 10 attempts per member and 3 per recipient per
hour per node. These mail budgets do not spend the manual-link budget. There are no
automatic retries or background jobs. Transport errors leave the invitation valid
and show an error; transport acceptance is not proof of receipt. Email-as-identifier
remains an application-level customization.

## Generated pages

| Route | Purpose |
| --- | --- |
| `/` | Protected home with invitation creation |
| `/setup` | Operator-code entry and first-account setup; closes after the instance is claimed |
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

**Deployment remains yours.** Generate the setup code with the release command in
the generated operations guide and enter it over HTTPS. Without a code, an empty
instance cannot be claimed. Rate limits are in-memory and per node; restarts reset
them. Configure trusted proxies or edge limits for client-IP requests, and use a
shared account-keyed limit if manual-link quotas must hold across multiple nodes.
The generated operations guide includes a recurring auth-cleanup command.
The healthcheck proves HTTP liveness, not database readiness. Migrations and cleanup
never run automatically during application boot.

Generated applications share `mise dev`, `mise reset`, `mise migrate`, `mise setup-code` and
`mise release`. Reset explicitly recreates the development database; release
builds provide `bin/migrate`, `bin/setup-code` and `bin/server` for the target machine.
