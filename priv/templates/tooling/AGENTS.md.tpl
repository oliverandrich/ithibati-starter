# Project instructions

Read [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and checks.

## Workflow

- Implement only the requested work. Backlog items do not authorize additional
  features. Preserve existing tooling during ordinary feature work.
- Use TDD for behavior changes: write a focused test, confirm the intended failure,
  implement the smallest passing change, then refactor with tests green. Reproduce
  bugs with a regression test first. For new tests of existing behavior, verify the
  assertion with a temporary targeted fault and restore the code. Setup failures
  do not count as red. Documentation-only changes need no new tests; explain when
  a meaningful red phase cannot be demonstrated.
- Run `mise run check` after changes; format explicitly with `mise run format`.
  Run dependency audits separately with `mise run audit`. Report check results
  and any checks that could not run. Read CONTRIBUTING for project-specific gates.
- Before a requested commit, review for bugs, regressions, security issues and
  rule violations. Simplify unnecessary branches and duplication without expanding
  scope, and rerun affected checks after edits. For documentation, review wording,
  consistency and links.
- Use Conventional Commits (`type(scope): short description`) with a short body
  explaining why and what changed; omit the body for self-explanatory changes.
  Commit or push only when explicitly requested.
- Do not run unattended migrations, resets or measurements against development
  data. Use disposable databases for experiments; a reset requires explicit scope.

## Work tracking

When local Beans tracking is configured:

- Search unfinished work before creating a ticket. Read the matching ticket and
  its parent/dependencies. Track progress there; do not create parallel TODO files
  or backlog comments in source. Complete one task before starting unrelated work.
- Mark work completed only after its acceptance criteria and checks pass, and add
  a `Summary of Changes`. For scrapped work, add `Reasons for Scrapping`.
- `beans list --ready` omits some unfinished work. Use `mise run beans` where
  available, or `beans list --no-status completed --no-status scrapped`.
- Keep new `.beans/` files and `.beans.yml` local and ignored. Do not force-add them,
  add ignore exceptions or remove already tracked tickets without instruction.
  Archive only when requested. Git pushes do not back up ignored tickets.
- Keep Bean IDs in Beans, not application code, tests, assets or README.
  Run `beans check` before finishing tracked work.

## Documentation structure

Keep the same division in the starter and all applications:

- `README.md`: project overview, features, a short getting-started path and links.
- `CONTRIBUTING.md`: development setup, mise commands, tests and contribution workflow.
- `AGENTS.md`: authoritative instructions for coding agents and project-specific rules.
- `docs/`: actual application or library documentation: usage, configuration,
  operations, architecture and public extension interfaces.

Do not put agent instructions or a second contributor guide under `docs/`.
Keep detailed explanations in one place and link to them. Update links when moving
content. Preserve project-specific documentation; common structure does not imply
identical application features. Other agent entry points such as `CLAUDE.md` refer
to `AGENTS.md` and do not maintain another set of rules.

## Authentication scope

An account is named or addressed, and `__MODULE__.Identity` answers which. The two
modes are one column and one format; the identifier field is fixed when the schema
compiles, so neither schema may carry `:format`. Ask `Identity` instead, in the
schema, the screen and the sentence. `:operator_code` is the only supported claim
mode. Do not add Ithibati's `:open` mode, a second identifier column, or a
registration path that skips an invitation.

Authentication budgets are keyed by `conn.remote_ip`. `__MODULE__Web.ClientIp`
supplies that address and believes `X-Forwarded-For` only on a connection from the
loopback or from `TRUSTED_PROXIES`. Keep the plug ahead of the request id.

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
For application repositories and generated templates, keep these commands aligned
with Ithibati Starter:

- `setup`: install dependencies, prepare the development database and build assets.
- `debugserver`: development server with IEx in `MIX_ENV=dev`.
- `dev`: foreground Phoenix server in `MIX_ENV=dev`, without tmux or an agent.
- `reset`: `mix ecto.reset` in `MIX_ENV=dev`; drops and recreates the development
  database, including migrations and seeds. Run only when explicitly requested.
- `migrate`: explicit development migrations.
- `release`: compile assets and build a production release for the build platform.
- In the unpacked release, `bin/migrate` applies migrations, `bin/setup-code`
  issues the first-account code and `bin/server` starts the HTTP server. Startup
  never runs migrations automatically.

Application-specific asset builds and quality checks remain in Mix aliases.

Deployment-specific configuration belongs in `config/runtime.exs` and environment
variables, not compiled installation paths. Keep releases movable, and put writable
data outside the release using configurable absolute paths. `rel/overlays/bin`
contains application start and migration commands, not host provisioning.
Validate native libraries and OS/architecture compatibility on the actual target.
VM resource settings must remain operator-configurable; do not promise memory usage
or pin shared-host tuning as a universal default without measurements.

## UI conventions

Use vanilla Tailwind utility classes for UI. Do not add DaisyUI or depend on its
component classes or theme tokens. CoreComponents and Layouts are owned by this app.
