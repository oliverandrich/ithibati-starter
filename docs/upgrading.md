# Upgrading generated applications

A generated application owns its code. The installer does not upgrade it: reapplying
the same version and profile changes nothing, and a different version or profile is
refused. Later starter changes reach an application by hand, through the workflow
below. The [changelog](../CHANGELOG.md) lists what each version changes.

## Identify the installed version

`.ithibati-starter` in the application root records the version and the profile:

```text
0.5.0
auth=true
beans=true
```

From 0.7.0 on, a fourth line records the brand colour, for example `brand=violet`.
From 0.9.0 on, a fifth line records the license, `license=mit` or `license=agpl`.
From 0.9.1 on, the `beans=` line is gone, because generated applications no longer configure Beans.

The `ithibati_starter` entry in `mix.lock` records the exact version, or the commit for a
version installed from Git.

## Compare two reference applications

Generate two fresh applications with the application's own name and profile, one
from the installed version and one from the target version. Install the `ithibati_new`
archive and the generators as described in the [usage guide](usage.md), then:

```sh
mkdir old new
(cd old && mix ithibati.new my_app --starter ithibati_starter@0.9.0)
(cd new && mix ithibati.new my_app --starter ithibati_starter@NEXT)
diff -ruN -x deps -x _build -x mix.lock -x .git old/my_app new/my_app > upgrade.diff
```

Versions before 0.9.0 are not on Hex. For one of those, pass its Git tag instead, for
example `--starter ithibati_starter@github:oliverandrich/ithibati-starter@v0.8.1`.
Before 0.9.1, add `--without-beans` to the source command if the profile says `beans=false`. Add
`--brand COLOUR` to the target command if the application should keep a colour other
than violet. Add `--license agpl --source-url URL` to the target command for an AGPL
application, and `--copyright NAME` when git has no `user.name`.

The diff contains changes that are not upgrades. Skip these hunks:

- `signing_salt`, `encryption_salt` and `secret_key_base`. Each generation creates
  new values. Replacing the application's values signs out every member.
- The `ithibati_starter` dependency in `mix.exs`. Set its requirement to the target
  version instead. An application installed from Git switches to the Hex requirement.

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

The installer refuses to change a profile. The brand colour and the license are the
remaining choices. To change the brand colour, edit the `signal` tokens in
`assets/css/app.css` and the `brand=` line. To change the license, replace `LICENSE`,
the README's license section and the `license=` line. Moving to AGPL also needs
`:source_url` in `config/config.exs`.

## Changes that need operator review

Check the diff for these before deploying:

- New files under `priv/repo/migrations/`. Back up the database first.
- New or changed environment variables in `config/runtime.exs` and
  `docs/operations.md`. A value outside the documented set can stop the boot.
- Changed release commands under `rel/overlays/bin` or changed start behavior.
- Dependency requirement changes in `mix.exs`. Review them like any dependency
  update.
