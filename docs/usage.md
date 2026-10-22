# Using Ithibati Starter

The [README](../README.md) shows how to create an application. This page covers the
options and what the generated application contains. Examples use an application
named `my_app`, module `MyApp`.

Links to Authentication, Operations and Interface lead to the generated application's guides.
They appear under "Generated application" on HexDocs. In the repository they are templates
under `priv/templates/*/docs/`.

## Options

```sh
mix ithibati.new PATH [--brand COLOUR] [--license mit|agpl] [--copyright NAME] \
  [--source-url URL] [--starter SOURCE] [--no-yes]
```

| Option | Effect |
| --- | --- |
| `--brand` | Tailwind palette for the brand colour, `violet` by default. See [Colours](#colours). |
| `--license` | `mit` (default) or `agpl`, meaning `AGPL-3.0-or-later`. Writes `LICENSE` and the README's license section. |
| `--source-url` | Required with `agpl`. Every layout links to it, as AGPL §13 requires. |
| `--copyright` | Copyright holder. Defaults to git's `user.name`. |
| `--starter` | Starter source for Igniter, `ithibati_starter@0.10.0` by default. |
| `--no-yes` | Ask before each installation step. |

Every source file gets an `SPDX-License-Identifier` line, and a generated test checks new
files. Code under `vendor/` keeps its own header.

`--starter` also takes a Git revision or a local checkout:

```sh
mix ithibati.new my_app --starter ithibati_starter@github:oliverandrich/ithibati-starter@v0.8.1
mix ithibati.new my_app --starter ithibati_starter@path:/absolute/path/to/ithibati-starter
```

A local checkout needs the archive from the same checkout: run `mix archive.build` and
`mix archive.install` in its `installer/` directory. Versions before 0.10.0 are only on
GitHub. The generated `mix.lock` records the starter version.

The archive wraps Igniter. This command is equivalent:

```sh
mix igniter.new my_app --with phx.new --install ithibati_starter@0.10.0 --only dev
```

## Accounts

`ACCOUNT_IDENTITY` decides at runtime whether an account is a username or an email
address. It is a runtime setting so that one release can serve both kinds of instance.
Each instance chooses once, before the first account. Identifiers keep the format they
were written in. A release that migrates on start refuses to start when its accounts
contradict the setting.

- **Named** (default): an invitation is a link with a note. The invitee chooses the
  username. No mail is sent.
- **Addressed**: the link is mailed to the invitee, which proves the address. The
  instance refuses to start without `MAIL_ENABLED=true` and the `SMTP_*` variables.

A signed-in account can create 20 invitations per day. The account that claims the
instance is an administrator. [Authentication](authentication.md) has the policy and
[Operations](operations.md) the variables.

In development, mail appears at `/dev/mailbox`. Tests use the Swoosh test adapter.

## Routes

| Route | Page |
| --- | --- |
| `/` | Home, signed in |
| `/setup` | Operator code and first account; closes once the instance is claimed |
| `/login`, `/recover` | Sign-in with a passkey or a recovery code |
| `/invite` | Accept an invitation |
| `/recovery-codes` | Show new recovery codes once |
| `/account/settings` | Account settings |
| `/account/passkeys` | Passkeys, and sign-out on all devices |
| `/account/recovery-codes` | Remaining codes and regeneration |
| `/account/invitations` | Create and list invitations |
| `/account/verify` | Confirm identity before a sensitive change |
| `/accounts` | Accounts and roles, managed by administrators |
| `/health` | Liveness probe |
| `/dev/mailbox` | Development mail |

## Layouts and components

`Layouts.auth/1` frames the sign-in screens. `Layouts.member/1` frames signed-in pages:
a sidebar from `lg`, a top bar and tab bar below. `MyAppWeb.Navigation.items/1` lists the
places. A page can choose `layout={:sidebar}` or `layout={:columns}`.
[Interface](interface.md) explains both.

`MyAppWeb.CoreComponents` replaces the Phoenix components:

| Component | Renders |
| --- | --- |
| `<.alert>` | A message in the page flow |
| `<.copy_field>` | A value with a copy button and a status line |
| `<.card>` | A raised area |
| `<.group>`, `<.group_link>` | Rows in a card, and a row linking to another page |
| `<.confirm_dialog>` | A modal with one question |
| `<.header>` | A page heading |
| `<.button>`, `<.input>` | A button or link, and a form field |
| `<.table>`, `<.list>` | A table and a data list |
| `<.flash>` | Flash notices |

## Colours

Templates name colours by role: `bg-surface`, `text-muted`, `border-edge`. `assets/css/app.css`
defines the roles as Tailwind theme variables, once for light and once for dark mode. A
template that uses them needs no `dark:` variant. [Interface](interface.md) lists the roles
and the type scale.

`--brand` accepts `red` `orange` `amber` `yellow` `lime` `green` `emerald` `teal` `cyan`
`sky` `blue` `indigo` `violet` `purple` `fuchsia` `pink` `rose`. Only the `signal` tokens
use it.

## Databases

`MY_APP_DATABASE` chooses `sqlite` (default) or `postgres` at runtime. `MyApp.Repo`
delegates to `MyApp.Repo.SQLite` or `MyApp.Repo.Postgres`. Migrations must work on both.
`mise run check` runs the tests on both.

## Limits

- Tested on fresh Phoenix 1.8.16 applications. `--binary-id` is refused.
- Rerunning with the same version, brand and license is a no-op. Any change is refused.
  [Upgrading](upgrading.md) covers newer versions.
- The browser's `Accept-Language` picks English or German. There is no language switch.
- Rate limits live in memory, per node.
- `/health` does not check the database.
- Oban runs the auth cleanup every hour, on the application's database.
