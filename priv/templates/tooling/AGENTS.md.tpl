# Project instructions

Read CONTRIBUTING.md. Use test-driven development: reproduce intended failures before
implementation, then refactor with tests green. For tests of existing behavior,
verify the assertion with a temporary targeted fault and restore it. Setup failures
are not a red phase; explain any limitations. Documentation needs no new tests.

Run `mise run check`; use `mise run format` explicitly. Run audits separately.
Use Conventional Commits (`type(scope): summary`) with a short reason/result body,
except self-explanatory changes. Before committing, review for bugs, regressions,
security and rule violations; simplify unnecessary branches/duplication and rerun
checks. Commit and push only when asked. Project tools need no personal skills.

Use vanilla Tailwind utility classes for UI. Do not add DaisyUI or depend on its
component classes or theme tokens. CoreComponents and Layouts are owned by this app.

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
