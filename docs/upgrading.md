# Upgrading generated applications

The installer does not upgrade an application. Rerunning it with the same version, brand
and license changes nothing; anything else is refused. Apply a newer version by hand.
The [changelog](../CHANGELOG.md) lists what each version changes.

## Find the installed version

`.ithibati-starter` records it:

```text
0.9.0
auth=true
brand=violet
license=mit
```

Older files may lack `brand=` (before 0.7.0) or `license=` (before 0.9.0), or carry a
`beans=` line (before 0.9.1).

## Diff two fresh applications

Generate the installed and the target version with the application's name and options:

```sh
mkdir old new
(cd old && mix ithibati.new my_app --starter ithibati_starter@0.9.0)
(cd new && mix ithibati.new my_app --starter ithibati_starter@NEXT)
diff -ruN -x deps -x _build -x mix.lock -x .git old/my_app new/my_app > upgrade.diff
```

Pass `--brand`, `--license`, `--source-url` and `--copyright` to each command that knows
them: `--brand` exists from 0.7.0, the license options from 0.9.0. Versions before
0.9.0 come from GitHub, for example
`--starter ithibati_starter@github:oliverandrich/ithibati-starter@v0.8.1`. Before 0.9.1,
add `--without-beans` if the old file says `beans=false`.

## Apply the diff

Skip the `signing_salt`, `encryption_salt` and `secret_key_base` hunks. Changing them signs
everybody out. Set the `ithibati_starter` requirement in `mix.exs` to the target version.

Apply the rest hunk by hunk. Copy new migrations with their timestamps. Then:

```sh
mix deps.get
mix deps.unlock --unused
mise run check
```

Set the first line of `.ithibati-starter` to the target version.

Before deploying, check new migrations, new variables in `config/runtime.exs` and changed
release scripts under `rel/overlays/bin`.

## Change brand or license

- **Brand**: edit the `signal` tokens in `assets/css/app.css` and the `brand=` line.
- **License**: replace `LICENSE`, the README's license section, the `SPDX-License-Identifier`
  lines and the `license=` line. AGPL also needs `:source_url` in `config/config.exs`.
