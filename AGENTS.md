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
