# Upgrading generated applications

A generated application owns its code. The installer does not upgrade it: reapplying
the same version and profile changes nothing, and a different version or profile is
refused. Later starter changes reach an application by hand, through the workflow
below. The [version notes](#version-notes) list what each version changes.

## Identify the installed version

`.ithibati-starter` in the application root records the version and the profile:

```text
0.5.0
auth=true
beans=true
```

From the next version on, a fourth line records the brand colour, for example
`brand=violet`.

The `ithibati_starter` entry in `mix.lock` records the exact commit.

## Compare two reference applications

Generate two fresh applications with the application's own name and profile, one
from the installed tag and one from the target tag. Install the `ithibati_new`
archive and the generators as described in the [usage guide](usage.md), then:

```sh
mkdir old new
(cd old && mix ithibati.new my_app \
  --starter ithibati_starter@github:oliverandrich/ithibati-starter@v0.5.0)
(cd new && mix ithibati.new my_app \
  --starter ithibati_starter@github:oliverandrich/ithibati-starter@vNEXT)
diff -ruN -x deps -x _build -x mix.lock -x .git old/my_app new/my_app > upgrade.diff
```

Add `--without-beans` to both commands if the profile says `beans=false`. Add
`--brand COLOUR` to the target command if the application should keep a colour other
than violet.

The diff contains changes that are not upgrades. Skip these hunks:

- `signing_salt`, `encryption_salt` and `secret_key_base`. Each generation creates
  new values. Replacing the application's values signs out every member.
- The `ithibati_starter` dependency in `mix.exs`. Point its `ref` at the target tag
  instead.

## Apply the changes

Apply the remaining hunks to the application one at a time. Where the application
changed a generated file, merge the starter's change into that version. Copy new
migrations unchanged, with their original timestamps.

Then update the dependencies and run the generated checks:

```sh
mix deps.get
mix deps.unlock --unused
mise run check
```

Finally, change the first line of `.ithibati-starter` to the target version.
Reapplying the installer is then a no-op again.

## Profile changes

The installer refuses to change a profile. Beans and the brand colour are the
remaining choices. To add or remove Beans, generate reference applications of both
profiles at the installed version and apply their diff. Then update the `beans=` line
in `.ithibati-starter`. To change the brand colour, edit the `signal` tokens in
`assets/css/app.css` and the `brand=` line.

## Changes that need operator review

Check the diff for these before deploying:

- New files under `priv/repo/migrations/`. Back up the database first.
- New or changed environment variables in `config/runtime.exs` and
  `docs/operations.md`. A value outside the documented set can stop the boot.
- Changed release commands under `rel/overlays/bin` or changed start behavior.
- Dependency requirement changes in `mix.exs`. Review them like any dependency
  update.

## Version notes

Each entry names what changed in generated applications and what to do about it.

### Unreleased

**The invitation page starts a ceremony only for an open invitation.**
`lib/my_app_web/live/invite_live.ex` ignores `accept` until a token has opened an invitation.
A page opened without a link now asks for the link instead of calling it used or expired.
`priv/gettext` gains that sentence and its German translation.
`lib/my_app_web/live/inside_live.ex` reports a missing address before a missing note.
`test/my_app_web/invite_live_test.exs` and `invitation_delivery_test.exs` cover these.

**A new invitation link has a copy button.** `lib/my_app_web/live/inside_live.ex` shows a copy
icon beside the link and a status line below the box. The new `assets/js/copy_text.js` holds
`copyText` and the `CopyText` hook. Import `CopyText` in `assets/js/app.js` and add it to the
LiveSocket's `hooks`.
`assets/js/recovery_codes.js` copies through `copyText`. `priv/gettext` gains three sentences.
`test/my_app_web/inside_live_test.exs` and `test/features/invitation_test.exs` cover the button.

### 0.7.0

**Colours are named by role.** `assets/css/app.css` gains an `@theme` block with role
tokens, their dark-mode values and a `text-link` utility. Every generated template
under `lib/` uses those tokens instead of `zinc`, `violet`, `indigo`, `red`, `sky` and
`emerald` classes. Neutral greys replace zinc, and primary buttons use ink. The brand
colour marks the wordmark dot, link underlines and the copy status of recovery codes. The auth layout
drops its radial gradient. `Layouts.wordmark/1` is new. `CoreComponents.alert/1` and
`CoreComponents.card/1` replace the copied error boxes and cards. Link underlines use
`signal-strong`, which keeps them visible for light palettes such as yellow.
`test/features/tailwind_test.exs` compares the light and dark page backgrounds
instead of expecting white. `test/my_app_web/components/core_components_test.exs`
checks `border-danger` and `border-edge`, and adds tests for `alert/1` and `card/1`.
`.ithibati-starter` gains a `brand=` line.

Applying this by hand touches most templates. Take the diff of the files you have not
changed, and keep your own colours in the files you have.

**One build serves SQLite and PostgreSQL.** `lib/my_app/repo.ex` becomes a dispatcher over
the new `lib/my_app/repo/sqlite.ex` and `lib/my_app/repo/postgres.ex`. `mix.exs` adds
`ecto_sqlite3`. `config/config.exs`, `dev.exs`, `test.exs` and `runtime.exs` read
`MY_APP_DATABASE`; a release then needs `DATABASE_PATH` or `DATABASE_URL`.
`test/test_helper.exs` runs SQLite tests one module at a time and skips the browser features
on PostgreSQL. `test/support/data_case.ex` and `FeatureCase` empty the rate limiter between
SQLite tests. `mise.toml` checks both databases. New tests are `test/my_app/repo_test.exs`
and `test/my_app/database_runtime_test.exs`.

For operators: **an existing PostgreSQL installation must set `MY_APP_DATABASE=postgres`**.
Without it the updated release starts on SQLite and stops for want of `DATABASE_PATH`.
Moving existing data between the databases is not covered.

**The check scans for secrets.** `mise.toml` pins gitleaks and runs `gitleaks git` in `check`
over the history, the staged and the unstaged changes. `.gitleaks.toml` allows the development
and test `secret_key_base`. The CI checkout fetches the full history with `fetch-depth: 0`. An
application with history may need further exceptions in `.gitleaks.toml`, each with its reason.

**A release logs JSON.** `mix.exs` adds `logger_json`. `lib/my_app/logging.ex` holds the
formatter, the metadata allowlist and the `LOG_LEVEL` parser, tested in
`test/my_app/logging_test.exs`. `config/runtime.exs` sets them for `:prod`. `config/prod.exs`
turns Phoenix's request log off. For operators: log lines change from text to JSON, and
`LOG_LEVEL=debug` stops the boot.

**A named invitee chooses the username, and invitation links carry the token after `#`.**
`mix.exs` requires Ithibati 0.8.1. The new migration
`priv/repo/migrations/20261017000000_open_invitations.exs` moves the invitation table to schema
version 5. Named, `lib/my_app/invitations.ex` writes an open invitation with a required note.
`lib/my_app_web/live/inside_live.ex` asks for that note and lists it. `lib/my_app_web/auth.ex`
takes the name the invitee chose and refuses one that is malformed or taken before the challenge.
The router serves `live "/invite", InviteLive`. `lib/my_app_web/live/invite_live.ex` waits for the
token from the new `assets/js/invitation_link.js`, which `assets/js/app.js` imports and registers
as the `InvitationLink` hook. `test/my_app_web/invite_live_test.exs` is new; `auth_test.exs`,
`inside_live_test.exs`, `invitation_delivery_test.exs` and `test/features/invitation_test.exs`
follow the new flow. The German translation of the invitation mail subject now matches its key.

For operators: links in the old form `/invite/TOKEN` stop working. Withdraw pending
invitations and issue new ones after the upgrade. Addressed instances keep the bound address.

**The browser features share one Chrome session.** `test/support/browser_pool.ex` is new.
`test/support/feature_case.ex` takes the session from it instead of `use Wallaby.Feature`, and
`test/test_helper.exs` starts and stops it. `test/features/browser_pool_test.exs` checks the
reset between features.

**A test names the generated files that differ from the starter.** `test/support/starter_drift.ex`
and `test/my_app/starter_drift_test.exs` are new. They compare every generated Elixir file with its
template in the locked starter, as syntax trees. An application with changed files lists them in
`@owned`. `lib/my_app_web/components/core_components.ex` and `layouts.ex` are now copied whole;
their content is unchanged.

**Member pages release their WebSocket heap after joining.** `lib/my_app_web/transport_garbage.ex`
is an `on_mount` hook of the `:members` live_session in the router. `config/test.exs` turns it
off for `Phoenix.LiveViewTest`. `test/my_app_web/transport_garbage_test.exs` covers it.

### 0.6.0

**The session cookie lasts as long as the session.** `lib/my_app_web/endpoint.ex`
replaces `plug Plug.Session, @session_options` with `plug :session` and a `session/2`
function that sets `max_age` from `Ithibati.Identity.Sessions.max_age()`. Without it
the browser drops the cookie when it closes. Members signed in before the change keep
their old cookie until their session next changes. `test/my_app_web/hardening_test.exs`
adds a test for the cookie's max age.

**Tidewave is no longer added.** The `:tidewave` dependency and the `plug Tidewave`
block in the endpoint are gone from new applications. Removing them from an existing
application is optional. Delete both, then run `mix deps.unlock --unused`.

**A release migrates its database on start.** `lib/my_app/application.ex` starts
`Ecto.Migrator` after the repo. `config/runtime.exs` reads `MY_APP_MIGRATE_ON_START`
in production. `test/my_app/migrate_on_start_test.exs` covers the variable. For
operators:

- Every start migrates, including `bin/setup-code`. Back up the database before
  starting a new release.
- `MY_APP_MIGRATE_ON_START=false` keeps the previous behavior: run `bin/migrate`
  before `bin/server`.
- Any value other than unset, `true` or `false` stops the boot.
- Before a rollback, stop the new release so a restart cannot migrate again.

`docs/operations.md` describes the new start sequence.
