# Ithibati Starter

An Igniter installer and the Phoenix templates it writes. The repository has no server and
no database of its own. [CONTRIBUTING.md](CONTRIBUTING.md) has the setup, commands and
release steps.

## Workflow

- Do only the requested work. A backlog item is no licence for more.
- Write a failing test first, and confirm it fails for the intended reason. For a test of
  existing behaviour, break the code briefly and restore it. A setup error is not red.
- Run `mise run check` after every change. Run the integration suite when generated code
  changes. Report what ran and what failed.
- Commit or push only when asked. Review the diff first. Use Conventional Commits.
- Never run migrations or resets against development data you did not create.

## Templates

- Generated behaviour and its tests live in `priv/templates/`. Installer steps live in `lib/`.
- `__APP__` and `__MODULE__` are replaced everywhere in a `.tpl` file, including inside a
  module body. Write `__MODULE__.Name` where the module itself is meant.
- One profile. `ACCOUNT_IDENTITY` names or addresses accounts at runtime. `MyApp.Identity`
  answers it, and neither schema carries a literal `:format`.
- `:operator_code` is the only claim mode. The generated application checks it at start.
- Every change to a generated file gets a changelog entry that says what an existing
  application has to do.

## Documentation

- `README.md`: what it is, how to start, links.
- `CONTRIBUTING.md`: development and release.
- `AGENTS.md`: rules for agents.
- `docs/`: usage, configuration and operations.

Keep each fact in one place and link to it. Keep docs short: one sentence, one fact.
Generated applications follow the same division.

## Generated applications

- A release migrates on start unless `MY_APP_MIGRATE_ON_START=false`. `bin/migrate`,
  `bin/setup-code`, `bin/server` and `bin/grant-admin` ship in `rel/overlays/bin`.
- Runtime settings go in `config/runtime.exs` and environment variables. Data lives
  outside the release, at configurable absolute paths.
- Hosting is the operator's. The `Dockerfile` builds an image; no Compose stacks,
  deployment scripts, registries, backups or host schedulers unless asked. Recurring work in
  the application runs in Oban.
- The mise tasks `setup`, `dev`, `debugserver`, `reset`, `migrate`, `setup-code` and
  `release` keep the same names in every application.
