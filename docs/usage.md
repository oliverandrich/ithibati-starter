# Using Ithibati Starter

## Get started

You'll need **mise**, **Elixir 1.20.4 / OTP 29.0.6** and **PostgreSQL 18**.
Chrome and a matching Chromedriver are required for the browser tests.
Node.js is not required: Mix manages Tailwind and esbuild.

Install the pinned generators and the starter archive once:

```sh
mix archive.install hex phx_new 1.8.14
mix archive.install hex igniter_new 0.5.34
mix archive.install github oliverandrich/ithibati-starter tag v0.4.0 --sparse installer
```

Create a Phoenix app with the starter:

```sh
mix ithibati.new my_app
cd my_app
```

The `ithibati_new` 0.4.0 archive selects Starter tag `v0.4.0` by default. Check
the `ithibati_starter` entry in the generated `mix.lock` to identify the exact
resolved commit. `--starter` accepts another tag, commit or local checkout. The
0.4.0 tag generates applications with Ithibati 0.6.0 and schema version 4.

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
  --install ithibati_starter@github:oliverandrich/ithibati-starter@v0.4.0 \
  --only dev
```

Then enter `my_app` and run the mise setup steps above.

</details>

<details>
<summary>Install from a local starter checkout</summary>

Build the archive from the checkout's `installer/` directory:

```sh
mix archive.build
mix archive.install ithibati_new-0.4.0.ez
```

Then, from the directory where the new project should live:

```sh
mix ithibati.new my_app \
  --starter ithibati_starter@path:/absolute/path/to/ithibati-starter
```

</details>

## One profile, one choice left to the operator

Every generated application gets the same thing: the Phoenix tooling, checks and CI,
vanilla Tailwind with Lucide and browser locale detection, passkeys with invitations
and account security, a Swoosh mailer with a local mailbox preview, and the
healthcheck, release helpers and auth cleanup. What an account is called is not
chosen when you generate it but when you run it.

**`--without-beans`** is the only switch, and it omits local tracking. Beans itself is
installed separately and is not needed to compile, test or run the app. Neither RTK
nor personal AI skills are required by generated applications.

## Naming or addressing accounts

**An account is a username or an email address, and the instance decides which**
through `ACCOUNT_IDENTITY`. Named is the default. Ithibati binds the identifier
field when a schema compiles, so the two modes are one column and the format is the
whole difference; `MyApp.Identity` answers it, and both schemas ask.

Named, an invitation is a link its maker passes on however they like. Nothing is
sent and no mail is configured. The form allows 20 creations per signed-in account
per day per node, counted against the account rather than the browser. A day rather
than an hour, because an addressed invitation spends the operator's mail
credentials, and the risk is a held account dripping rather than a burst.

Addressed, the invitee's identifier is an email address, the link is delivered to
it, and that delivery is what proves the address. It requires `MAIL_ENABLED=true`
and the `SMTP_*` variables; an instance that asks for addresses without being able
to send any refuses to start. A delivery that fails is reported and the link stays
shareable by hand, because the invitation exists before the delivery and the link
is the only copy there will ever be.

Choose once, before the first account. The generated `docs/operations.md` carries the
variables and `docs/authentication.md` the policy; this page does not restate them.

Development messages appear at **`/dev/mailbox`** and tests use the Swoosh test
adapter; neither sends external mail. Submission is authenticated and the server's
certificate is verified; port 465 is taken as implicit TLS and anything else as
STARTTLS. Other providers can replace the Swoosh adapter.

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
| `/dev/mailbox` | Development mail preview |

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
