# Project instructions

[CONTRIBUTING.md](CONTRIBUTING.md) has the setup and commands.

## Workflow

- Do only the requested work. A backlog item is no licence for more.
- Write a failing test first, and confirm it fails for the intended reason. For a test of
  existing behaviour, break the code briefly and restore it. A setup error is not red.
- Run `mise run check` after every change. Report what ran and what failed.
- Commit or push only when asked. Review the diff first. Use Conventional Commits.
- Never run migrations or `mise run reset` against development data unless asked.

## Documentation structure

- `README.md`: what the application is, how to start, links.
- `CONTRIBUTING.md`: development.
- `AGENTS.md`: rules for agents. `CLAUDE.md` and similar files point here.
- `docs/`: configuration, operations and architecture.

Keep each fact in one place and link to it.

## Authentication

- An account is named or addressed. `__MODULE__.Identity` answers which. Neither schema
  carries a literal `:format`; ask `Identity` in the schema, the screen and the message.
- `:operator_code` is the only claim mode. Do not add Ithibati's `:open` mode, a second
  identifier column, or a registration path without an invitation.
- Every administrator function takes the acting account first and runs through
  `__MODULE__.Accounts.with_admin/2`, which reads the flag from the database.
  `bin/grant-admin` is the operator's exception.
- Data an account owns references `users` with `on_delete: :delete_all`. Other cleanup that
  must roll back with the removal goes into `removed/1` in `__MODULE__.Accounts`.
- Rate limits count `conn.remote_ip`, which `__MODULE__Web.ClientIp` sets. Keep that plug
  ahead of the request id.

## Deployment

- Ship a Mix release. It migrates on start unless `__APP_UPCASE___MIGRATE_ON_START=false`.
- Runtime settings go in `config/runtime.exs` and environment variables. Data lives
  outside the release, at configurable absolute paths.
- Hosting is the operator's. The `Dockerfile` builds an image; no Compose stacks,
  deployment scripts, registries, backups or schedulers unless asked.
- Keep the mise tasks `setup`, `dev`, `debugserver`, `reset`, `migrate`, `setup-code` and
  `release`.

## Interface

Use plain Tailwind utilities. No DaisyUI. `CoreComponents` and `Layouts` belong to this
application.
