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

Add `--without-beans` to both commands if the profile says `beans=false`.

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

The installer refuses to change a profile. Beans is the only remaining choice. To add
or remove it, generate reference applications of both profiles at the installed
version and apply their diff. Then update the `beans=` line in `.ithibati-starter`.

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
