# Ithibati Starter

Elixir library containing an Igniter installer and Phoenix application templates.
Read [CONTRIBUTING.md](CONTRIBUTING.md) for setup, checks and development rules.

- Use TDD for behavior changes: focused test, intended red, smallest green change,
  then refactor. Reproduce bugs first. For new tests of existing behavior, verify
  the assertion with a temporary targeted fault and restore it. Explain when a
  meaningful red phase cannot be demonstrated. Documentation needs no new tests.
- Run `mise run check` after changes; `mise run format` explicitly formats files.
  Audits run separately with `mise run audit`.
- Use Conventional Commits (`type(scope): short description`) and a short body
  explaining why and what changed, except self-explanatory changes. Before a
  requested commit, review for bugs, regressions, security and rule violations,
  simplify unnecessary branches/duplication, then rerun affected checks.
  Commit or push only when requested.
- Track work in local Beans: search unfinished work before creating tickets,
  update progress, and finish with a Summary of Changes. Run `beans check`.
  `.beans/` and `.beans.yml` stay ignored and are not backed up by Git pushes.
- Preserve the established tooling for ordinary features. Use the personal setup
  skills only for explicit tooling modernization; project checks need no skills.
- Prefix shell commands with `rtk` when available.

## Deployment scope

Ship the application as a Mix release with its runtime: unpack, configure, run.
Keep explicit database migration commands and runtime configuration. Persistent
application data and secrets belong outside the release directory.

Database provisioning, process supervision, TLS, database dumps and OS-level
file backups are the operator's responsibility. Do not add Dockerfiles, Compose
stacks, deployment installers, self-updaters, or application-owned backup/restore
commands, retention, remote copies or schedules unless explicitly requested.
Database migration rollback and restoring user content are application concerns,
not infrastructure backup automation. CI service containers are unaffected.
Build and test for specific OS versions and architectures before claiming support.

## Common commands

Use mise as the entry point; `mise TASK` and `mise run TASK` are equivalent.
Keep these commands aligned with Ithibati Starter:

- `dev`: foreground Phoenix server in `MIX_ENV=dev`, without tmux or an agent.
- `reset`: `mix ecto.reset` in `MIX_ENV=dev`; drops and recreates the development
  database, including migrations and seeds. Run only when explicitly requested.
- `migrate`: explicit development migrations.
- `release`: compile assets and build a production release for the build platform.
- In the unpacked release, `bin/migrate` applies migrations and `bin/server`
  starts the HTTP server. Startup never runs migrations automatically.

Application-specific asset builds and quality checks remain in Mix aliases.

Deployment-specific configuration belongs in `config/runtime.exs` and environment
variables, not compiled installation paths. Keep releases movable, and put writable
data outside the release using configurable absolute paths. `rel/overlays/bin`
contains application start and migration commands, not host provisioning.
Uberspace targets U8 only; do not add U7 compatibility work. Validate native
libraries and OS/architecture compatibility on the actual target. VM resource
settings must remain operator-configurable; do not promise memory usage or pin
shared-host tuning as a universal default without measurements.
