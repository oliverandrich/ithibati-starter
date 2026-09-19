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

The archive shares the root mise runtimes, Credo rules, formatting, CI, audits and
Beans tracking. It has no dependencies of its own. `mise run check` additionally
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
| `priv/templates/fragments/` | Router, layout and documentation fragments |
| `test/fixtures/phoenix/` | The supported Phoenix scaffold, stored as `.txt` fixtures |
| `test/ithibati_starter_test.exs` | Installer behavior and profile tests |
| `scripts/integration.sh` | End-to-end generation and validation of both profiles |

Templates end in `.tpl`. `__APP__` becomes the OTP app name and `__MODULE__`
becomes the application's module name. These files are compiled only after they
have been rendered into a generated application. Keep aliases and embedded HTML
modules compatible with the generated project's quality checks.

Igniter is a required dependency; there is no optional-dependency build mode.
The initial support floor is Elixir 1.20 / OTP 29 with Phoenix 1.8.14 and PostgreSQL.

## Test real generated applications

Install **PostgreSQL 18**, **Chrome** and a **Chromedriver matching your Chrome
version**. Point the suite at a local PostgreSQL instance on which the test user
can create disposable databases:

```sh
export PGHOST=127.0.0.1
export PGPORT=5432
export PGUSER=postgres
export PGPASSWORD=postgres
export CHROMEWEBDRIVER=/absolute/path/to/chromedriver-directory
mise run integration
```

`CHROMEWEBDRIVER` is a directory containing the `chromedriver` executable. On
GitHub Actions it comes from the runner environment. Keep it in sync with Chrome
when testing locally. Missing browser tooling must fail the suite rather than
silently skip coverage.

The script installs the pinned generators and the local archive in an isolated
archive directory, then uses `mix ithibati.new` to create disposable default and
mail-enabled applications. It runs each application's full gate, checks that
reapplying the same profile is a no-op, builds both production releases, runs
their migrations twice against disposable databases and starts each over HTTP.
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
   aligned with the source templates.
5. **Review before committing.** Look for regressions, security issues and
   unnecessary complexity. Use Conventional Commits, such as
   `fix(auth): preserve recovery confirmation during input`, with a short body
   explaining why and what changed.

Documentation-only changes do not need new tests. If a meaningful red phase cannot
be demonstrated, explain the limitation rather than claiming TDD was followed.
See [AGENTS.md](https://github.com/oliverandrich/ithibati-starter/blob/main/AGENTS.md) for repository working conventions.

## Local work tracking

The maintainer uses [Beans](https://github.com/hmans/beans) locally. `.beans/` and
`.beans.yml` are ignored and are not included in Git pushes; Beans is not required
to build or test this repository.

When working in a checkout configured for Beans, search unfinished work before
creating a ticket, update progress, finish with a **Summary of Changes**, and run:

```sh
beans check
```

## Licensing and publication

Contributions are included under the [MIT license](https://github.com/oliverandrich/ithibati-starter/blob/main/LICENSE). Preserve [NOTICE](https://github.com/oliverandrich/ithibati-starter/blob/main/NOTICE)
and [THIRD_PARTY_LICENSES.md](https://github.com/oliverandrich/ithibati-starter/blob/main/THIRD_PARTY_LICENSES.md) when adapting upstream code.
Generated application code belongs in the consuming application's repository;
it does not load templates from this source checkout at runtime.

Checks and package builds never publish anything. GitHub publication, tags and Hex
releases are explicit maintainer actions.
