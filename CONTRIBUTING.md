# Contributing

Thanks for helping improve Ithibati Starter. This repository contains an Igniter
installer and the Phoenix templates it writes into new applications.

## Set up the repository

Install [mise](https://mise.jdx.dev), then clone and prepare the checkout:

```sh
git clone https://github.com/oliverandrich/ithibati-starter.git
cd ithibati-starter
mise trust
mise install
mise exec -- mix deps.get
mise run check
```

`mise.toml` pins Elixir, Erlang/OTP and zizmor. The installer tests do not need a
running database or browser. The integration suite does; see below.

## Command reference

| Command | Purpose |
| --- | --- |
| `mise run check` | Workflow audit, compilation, format/lock checks, strict Credo, installer tests and documentation build |
| `mise run test` | Installer tests only |
| `mise run format` | Format Elixir source explicitly |
| `mise run credo` | Compile and run strict Credo |
| `mise run integration` | Generate and check both real Phoenix profiles, including browser tests and production release builds and HTTP smoke checks |
| `mise run audit` | Dependency advisories and retired Hex packages, separate from the check gate |
| `mise exec -- mix hex.build` | Build a local package without publishing it |
| `mise run release-check` | Refuse a release that is not the commit a pushed version tag points at |

The archive shares the root mise runtimes, Credo rules, formatting, CI and audits. It has no dependencies of its own. `mise run check` additionally
compiles it, runs its tests and builds the archive; `mise run test` runs both suites.
This keeps the installable archive small without a separate tooling stack.

The check gate does not format files or rewrite the dependency lock. Run the
formatting command yourself after editing Elixir source.

## Find your way around

| Path | Contents |
| --- | --- |
| `installer/` | Dependency-free Mix archive providing `mix ithibati.new` |
| `lib/ithibati_starter/` | Installer transformations and template rendering |
| `lib/mix/tasks/` | Public installer task |
| `priv/templates/tooling/` | Files shared by both profiles |
| `priv/templates/mail/` | Optional invitation mailer, delivery and tests |
| `priv/templates/auth/` | Ithibati application code and generated auth tests |
| `priv/templates/fragments/` | Router, layout and configuration fragments |
| `docs/` | Starter usage and configuration documentation |
| `test/fixtures/phoenix/` | The supported Phoenix scaffold, stored as `.txt` fixtures |
| `test/ithibati_starter_test.exs` | Installer behavior and profile tests |
| `scripts/integration.sh` | End-to-end generation and validation of both profiles |

Templates end in `.tpl`. `__APP__` becomes the OTP app name and `__MODULE__`
becomes the application's module name. These files are compiled only after they
have been rendered into a generated application. Keep aliases and embedded HTML
modules compatible with the generated project's quality checks.

Igniter is a required dependency; there is no optional-dependency build mode.
The initial support floor is Elixir 1.20 / OTP 29 with Phoenix 1.8.16, SQLite and PostgreSQL.

## Test real generated applications

Install **PostgreSQL 18**. Point the suite at a local PostgreSQL instance on which the test user
can create disposable databases:

```sh
export PGHOST=127.0.0.1
export PGPORT=5432
export PGUSER=postgres
export PGPASSWORD=postgres
mise run integration
```

Each generated application installs Playwright and its Chrome for Testing through its own
`mise run browser`; no installed Chrome is needed. Missing browser tooling must fail the suite
rather than silently skip coverage.

The script installs the pinned generators and the local archive in an isolated
archive directory, then uses `mix ithibati.new` to create disposable default and
mail-enabled applications. It runs each application's full gate, checks that
reapplying the same profile is a no-op and builds both production releases. Each
release starts on an empty disposable PostgreSQL database and migrates it. A second
database covers the opt-out: migrations run twice by hand, then the release starts over
HTTP. The same release then starts on a new SQLite file, migrates it and serves HTTP.
The SQLite check needs the `sqlite3` command.
It chooses a test database partition and cleans up its temporary project
directory and release smoke databases. Cleanup of the partitioned test databases
remains the responsibility of the local test environment. Never use a development
or production database for these checks.

The auth tests exercise real WebAuthn ceremonies using Chrome virtual
authenticators; no hardware passkey is required. The test endpoint defaults to
port **43129** in the integration script. Override `PORT` if it is occupied.

## Make a change

1. **Choose the right layer.** Change installer behavior in `lib/`; change
   generated application behavior and its regression tests in `priv/templates/`.
2. **Start with a focused failing test for behavior changes.** Confirm that it
   fails for the intended reason, implement the smallest passing change, then
   refactor with tests green. For new tests of existing behavior, use a temporary,
   targeted fault to prove the assertion catches it, then restore the source.
3. **Run the relevant checks.** Run `mise run check` for every contribution and
   the integration suite when generated application behavior changes. Exercise
   both profiles and preserve reapplication behavior.
4. **Update documentation.** Explain new defaults, commands and operational
   limits. Preserve upstream attribution and keep the generated documentation
   aligned with the source templates. When behavior changes, add an entry under
   `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md). Name the changed generated
   files and what an existing application or its operator has to do.
   The release commit renames that heading to the version.
5. **Review before committing.** Look for regressions, security issues and
   unnecessary complexity. Use Conventional Commits, such as
   `fix(auth): preserve recovery confirmation during input`, with a short body
   explaining why and what changed.

Documentation-only changes do not need new tests. If a meaningful red phase cannot
be demonstrated, explain the limitation rather than claiming TDD was followed.
See [AGENTS.md](https://github.com/oliverandrich/ithibati-starter/blob/main/AGENTS.md) for repository working conventions.

## Documentation layout

The starter and generated applications use the same division: README for an
overview and quick start, CONTRIBUTING for development, AGENTS for agent rules,
and `docs/` for actual usage, configuration, operations and architecture guides.
Keep explanations in one place and update links when moving them.

Generated application guides live in the profile's `docs/` template directory.
Authentication and operations are always documented, including how an account is
named or addressed. Keep the installer tests covering it.

## Release a version

One tag publishes both packages to Hex. `.github/workflows/release.yml` runs the release.

1. Set the version in `mix.exs`, `installer/mix.exs`, the generated README and the
   docs. The archive's default starter and the version marker follow `mix.exs`.
   The tests pin each of these.
2. Rename `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md) to `## [VERSION] - DATE`.
   Add a new empty `## [Unreleased]` and the compare links at the end.
3. Run `mise run check` and `mise run integration`. Commit as
   `chore(release): VERSION` and push `main`.
4. Tag that commit and push the tag:

   ```sh
   git tag -a vVERSION -m vVERSION
   git push origin vVERSION
   ```

5. The workflow runs `mise run release-check` and the CI gate without caches.
   The `publish` job then waits for approval in the `hex` environment.
6. After approval, `publish` releases `ithibati_starter` first and `ithibati_new`
   second. The archive installs that starter version. `announce` then creates the
   GitHub release from the changelog section.

If `publish` fails after `ithibati_starter` is on Hex, re-run the failed job.
Each publish step skips a version that is already on Hex. hex.pm allows reverting a
version only shortly after publication; retire a broken version with `mix hex.retire`.
Never move a published tag; use a new version for later changes.

A `workflow_dispatch` run never publishes. Its `tag` job refuses unless HEAD carries
the version tag; on a tagged commit the CI gate runs as well.

The repository needs this setup once:

- A `hex` environment with the maintainer as required reviewer and a deployment
  policy that admits only `v*` tags.
- The environment secret `HEX_API_KEY`. Create the key under Keys in the hex.pm
  dashboard with API write permission. Hex 2.5 has no command for keys.
- A tag ruleset on `refs/tags/v*` that blocks deletion and force updates.

## Licensing and publication

Contributions are included under the [MIT license](https://github.com/oliverandrich/ithibati-starter/blob/main/LICENSE). Preserve [NOTICE](https://github.com/oliverandrich/ithibati-starter/blob/main/NOTICE)
and [THIRD_PARTY_LICENSES.md](https://github.com/oliverandrich/ithibati-starter/blob/main/THIRD_PARTY_LICENSES.md) when adapting upstream code.
Generated application code belongs in the consuming application's repository;
it does not load templates from this source checkout at runtime.

Checks and package builds never publish anything. GitHub publication, tags and Hex
releases are explicit maintainer actions.
