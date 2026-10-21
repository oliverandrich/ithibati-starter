# Contributing

## Setup

```sh
git clone https://github.com/oliverandrich/ithibati-starter.git
cd ithibati-starter
mise trust && mise install
mise exec -- mix deps.get
mise run check
```

## Commands

| Command | Does |
| --- | --- |
| `mise run check` | zizmor, compile, format, Credo, both test suites, archive build, docs |
| `mise run test` | Starter and installer tests |
| `mise run format` | Format the source |
| `mise run integration [mit\|agpl]` | Generate real applications and run their checks, releases and smoke tests |
| `mise run audit` | Dependency advisories |
| `mise run release-check` | Refuse a release that is not a pushed version tag |

`check` does not format. Run `mise run format` after editing.

## Layout

| Path | Contents |
| --- | --- |
| `installer/` | The `ithibati_new` archive, without dependencies |
| `lib/ithibati_starter/` | Installer steps and template rendering |
| `priv/templates/` | `tooling`, `auth`, `licenses` and `fragments` |
| `test/fixtures/` | Unmodified `phx.new` output the installer is tested against |
| `scripts/integration.sh` | The integration suite |

Templates end in `.tpl`. `__APP__` becomes the OTP app name and `__MODULE__` the module
name, everywhere in the file.

## Integration suite

It needs PostgreSQL 18, a user that can create databases, and `sqlite3`:

```sh
export PGHOST=127.0.0.1 PGPORT=5432 PGUSER=postgres PGPASSWORD=postgres
mise run integration
```

It generates each profile, runs the generated checks and browser tests, reapplies the
installer, and starts a release on PostgreSQL and SQLite. The test endpoint uses port
43129; set `PORT` to change it.

CI runs it only when a change can reach a generated application. Pushes and pull requests
run `agpl`; manual runs and releases run both and build the `Dockerfile` image.
`INTEGRATION_IMAGE=true` builds it locally too, which needs `docker`.

## Changes

- Installer behaviour goes in `lib/`, generated behaviour and its tests in `priv/templates/`.
- Write a failing test first.
- Run `mise run check`, and the integration suite when generated code changes.
- Add an entry under `## [Unreleased]` in the [changelog](CHANGELOG.md). Name the changed
  files and what an existing application has to do.
- Use Conventional Commits.

## Release

One tag publishes both packages.

1. Set the version in `mix.exs`, `installer/mix.exs` and the docs. The tests find every copy.
2. Rename `## [Unreleased]` to `## [VERSION] - DATE` and add the compare link.
3. Run `mise run check` and `mise run integration`. Commit `chore(release): VERSION`, push.
4. `git tag -a vVERSION -m vVERSION && git push origin vVERSION`.
5. Approve the `publish` job in the `hex` environment. It publishes `ithibati_starter`, then
   `ithibati_new`, then creates the GitHub release.

A failed publish can be rerun; published versions are skipped. Never move a tag. Retire a
broken version with `mix hex.retire` and release a new one.

The repository needs a `hex` environment with a required reviewer, a `v*` tag policy and
the secret `HEX_API_KEY`, and a ruleset that blocks deleting or moving `v*` tags.

## License

Contributions are [MIT](https://github.com/oliverandrich/ithibati-starter/blob/main/LICENSE).
