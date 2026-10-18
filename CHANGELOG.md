# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Entries name what changed in generated applications and what to do about it. Paths use
`my_app` for the application name. [Upgrading](docs/upgrading.md) describes how to apply
a version to an existing application.

## [Unreleased]

## [0.9.0] - 2026-10-18

Requires Ithibati 0.9.0. The schema version stays at 5, so no migration is needed.

### Added

- `ithibati_starter` and `ithibati_new` are published on Hex. Install the archive with
  `mix archive.install hex ithibati_new 0.9.0`. Versions before 0.9.0 remain available from
  their Git tags only.
- This changelog. It replaces the version notes in [Upgrading](docs/upgrading.md).
- `--license mit|agpl` chooses the application's license, MIT by default. The installer writes
  `LICENSE` and a license section with the copyright line in `README.md`. `--copyright NAME`
  names the holder; without it the installer takes git's `user.name`. `agpl` means `AGPL-3.0-or-later` and
  requires `--source-url URL`, which `config/config.exs` stores as `:source_url`.
  `.ithibati-starter` gains a `license=` line.
- Every layout can link to the source code. `lib/my_app_web/components/layouts.ex` gains
  `source_offer/1`, which `auth/1` and `member/1` render when `:source_url` is set.
  `config/runtime.exs` reads `SOURCE_URL` and refuses a value that is not an absolute http or
  https URL. `docs/operations.md` describes it. `priv/gettext` gains "Source code" and its German
  translation.

  An existing application has no `LICENSE` file. Add one, and the README section, by hand.
- Every source file states its license as `SPDX-License-Identifier` in its first five lines.
  The installer marks Elixir, HEEx, JavaScript and CSS files and the release start commands.
  It covers `lib`, `test`, `config`, `priv/repo`, `assets/js`, `assets/css` and `rel`.
  It also covers `mix.exs`, `.formatter.exs`, `.credo.exs` and `.igniter.exs`.
  Files under `vendor/` keep their own terms.
  The new `test/my_app/license_marker_test.exs` checks the same files.
  `CONTRIBUTING.md` explains the rule.
  An existing application adds the lines before it adopts the test.

### Changed

- `mix.exs` requires Ithibati `~> 0.9.0`. `docs/authentication.md`, `README.md` and
  `ITHIBATI_STARTER_NOTICE.md` name the new versions.
- `mix ithibati.new` installs `ithibati_starter` 0.9.0 from Hex instead of the Git tag. The
  generated `mix.exs` declares the starter with the requirement `"== 0.9.0"`. An existing
  application replaces its Git dependency with that requirement and keeps the other options.

## [0.8.1] - 2026-10-18

### Fixed

- The copy hook ignores a copy that finishes after the hook is destroyed. LiveView can destroy a
  hook while its element stays on the page; `assets/js/copy_text.js` checks for that as well.
  `test/features/invitation_test.exs` copies a second link and checks that its button starts
  without a check.

## [0.8.0] - 2026-10-18

### Added

- A new invitation link has a copy button. `lib/my_app_web/live/inside_live.ex` shows a copy
  icon beside the link and a status line below the box. The new `assets/js/copy_text.js` holds
  `copyText` and the `CopyText` hook. Import `CopyText` in `assets/js/app.js` and add it to the
  LiveSocket's `hooks`. `assets/js/recovery_codes.js` copies through `copyText`.
  `priv/gettext` gains three sentences. `test/my_app_web/inside_live_test.exs` and
  `test/features/invitation_test.exs` cover the button.
- A test pins HTTPS in production. `test/my_app_web/prod_config_test.exs` checks that
  `config/prod.exs` forces HTTPS with HSTS, trusts `X-Forwarded-Proto` and exempts local hosts.
  `docs/operations.md` says to reach the application only through the TLS proxy.

### Changed

- `config/runtime.exs` drops the scaffold's comment that recommends `force_ssl`.

### Fixed

- The invitation page starts a ceremony only for an open invitation.
  `lib/my_app_web/live/invite_live.ex` ignores `accept` until a token has opened an invitation.
  A page opened without a link now asks for the link instead of calling it used or expired.
  `priv/gettext` gains that sentence and its German translation.
  `lib/my_app_web/live/inside_live.ex` reports a missing address before a missing note.
  `test/my_app_web/invite_live_test.exs` and `invitation_delivery_test.exs` cover these.
- The starter's own Mint dependency is updated past known advisories.

## [0.7.0] - 2026-10-17

Requires Ithibati 0.8.1 and schema version 5.

### Added

- One build serves SQLite and PostgreSQL. `lib/my_app/repo.ex` becomes a dispatcher over
  the new `lib/my_app/repo/sqlite.ex` and `lib/my_app/repo/postgres.ex`. `mix.exs` adds
  `ecto_sqlite3`. `config/config.exs`, `dev.exs`, `test.exs` and `runtime.exs` read
  `MY_APP_DATABASE`; a release then needs `DATABASE_PATH` or `DATABASE_URL`.
  `test/test_helper.exs` runs SQLite tests one module at a time and skips the browser features
  on PostgreSQL. `test/support/data_case.ex` and `FeatureCase` empty the rate limiter between
  SQLite tests. `mise.toml` checks both databases. New tests are `test/my_app/repo_test.exs`
  and `test/my_app/database_runtime_test.exs`.

  For operators: **an existing PostgreSQL installation must set `MY_APP_DATABASE=postgres`**.
  Without it the updated release starts on SQLite and stops for want of `DATABASE_PATH`.
  Moving existing data between the databases is not covered.
- The check scans for secrets. `mise.toml` pins gitleaks and runs `gitleaks git` in `check`
  over the history, the staged and the unstaged changes. `.gitleaks.toml` allows the development
  and test `secret_key_base`. The CI checkout fetches the full history with `fetch-depth: 0`. An
  application with history may need further exceptions in `.gitleaks.toml`, each with its reason.
- A release logs JSON. `mix.exs` adds `logger_json`. `lib/my_app/logging.ex` holds the
  formatter, the metadata allowlist and the `LOG_LEVEL` parser, tested in
  `test/my_app/logging_test.exs`. `config/runtime.exs` sets them for `:prod`. `config/prod.exs`
  turns Phoenix's request log off.

  For operators: log lines change from text to JSON, and `LOG_LEVEL=debug` stops the boot.
- A test names the generated files that differ from the starter.
  `test/support/starter_drift.ex` and `test/my_app/starter_drift_test.exs` are new. They compare
  every generated Elixir file with its template in the locked starter, as syntax trees. An
  application with changed files lists them in `@owned`.
  `lib/my_app_web/components/core_components.ex` and `layouts.ex` are now copied whole; their
  content is unchanged.
- Member pages release their WebSocket heap after joining. `lib/my_app_web/transport_garbage.ex`
  is an `on_mount` hook of the `:members` live_session in the router. `config/test.exs` turns it
  off for `Phoenix.LiveViewTest`. `test/my_app_web/transport_garbage_test.exs` covers it.

### Changed

- Colours are named by role, and `--brand` chooses the brand colour. `assets/css/app.css`
  gains an `@theme` block with role tokens, their dark-mode values and a `text-link` utility.
  Every generated template under `lib/` uses those tokens instead of `zinc`, `violet`,
  `indigo`, `red`, `sky` and `emerald` classes. Neutral greys replace zinc, and primary buttons
  use ink. The brand colour marks the wordmark dot, link underlines and the copy status of
  recovery codes. The auth layout drops its radial gradient. `Layouts.wordmark/1` is new.
  `CoreComponents.alert/1` and `CoreComponents.card/1` replace the copied error boxes and
  cards. Link underlines use `signal-strong`, which keeps them visible for light palettes such
  as yellow. `test/features/tailwind_test.exs` compares the light and dark page backgrounds
  instead of expecting white. `test/my_app_web/components/core_components_test.exs` checks
  `border-danger` and `border-edge`, and adds tests for `alert/1` and `card/1`.
  `.ithibati-starter` gains a `brand=` line.

  Applying this by hand touches most templates. Take the diff of the files you have not
  changed, and keep your own colours in the files you have.
- A named invitee chooses the username, and invitation links carry the token after `#`.
  `mix.exs` requires Ithibati 0.8.1. The new migration
  `priv/repo/migrations/20261017000000_open_invitations.exs` moves the invitation table to schema
  version 5. Named, `lib/my_app/invitations.ex` writes an open invitation with a required note.
  `lib/my_app_web/live/inside_live.ex` asks for that note and lists it. `lib/my_app_web/auth.ex`
  takes the name the invitee chose and refuses one that is malformed or taken before the
  challenge. The router serves `live "/invite", InviteLive`.
  `lib/my_app_web/live/invite_live.ex` waits for the token from the new
  `assets/js/invitation_link.js`, which `assets/js/app.js` imports and registers as the
  `InvitationLink` hook. `test/my_app_web/invite_live_test.exs` is new; `auth_test.exs`,
  `inside_live_test.exs`, `invitation_delivery_test.exs` and `test/features/invitation_test.exs`
  follow the new flow.

  For operators: links in the old form `/invite/TOKEN` stop working. Withdraw pending
  invitations and issue new ones after the upgrade. Addressed instances keep the bound address.
- The browser features share one Chrome session. `test/support/browser_pool.ex` is new.
  `test/support/feature_case.ex` takes the session from it instead of `use Wallaby.Feature`, and
  `test/test_helper.exs` starts and stops it. `test/features/browser_pool_test.exs` checks the
  reset between features.

### Fixed

- The German translation of the invitation mail subject now matches its key.

## [0.6.0] - 2026-10-10

### Added

- A release migrates its database on start. `lib/my_app/application.ex` starts
  `Ecto.Migrator` after the repo. `config/runtime.exs` reads `MY_APP_MIGRATE_ON_START`
  in production. `test/my_app/migrate_on_start_test.exs` covers the variable.
  `docs/operations.md` describes the new start sequence.

  For operators:

  - Every start migrates, including `bin/setup-code`. Back up the database before
    starting a new release.
  - `MY_APP_MIGRATE_ON_START=false` keeps the previous behavior: run `bin/migrate`
    before `bin/server`.
  - Any value other than unset, `true` or `false` stops the boot.
  - Before a rollback, stop the new release so a restart cannot migrate again.
- [Upgrading](docs/upgrading.md) describes how to apply a later starter version.

### Removed

- Tidewave is no longer added. The `:tidewave` dependency and the `plug Tidewave` block in the
  endpoint are gone from new applications. Removing them from an existing application is
  optional. Delete both, then run `mix deps.unlock --unused`.

### Fixed

- The session cookie lasts as long as the session. `lib/my_app_web/endpoint.ex` replaces
  `plug Plug.Session, @session_options` with `plug :session` and a `session/2` function that
  sets `max_age` from `Ithibati.Identity.Sessions.max_age()`. Without it the browser drops the
  cookie when it closes. Members signed in before the change keep their old cookie until their
  session next changes. `test/my_app_web/hardening_test.exs` adds a test for the cookie's max age.

## [0.5.0] - 2026-10-07

Requires Ithibati 0.7.1.

### Added

- Members see the pending invitations, who created them, and can withdraw one.
  `lib/my_app/invitations.ex` holds the queries. A withdrawal cannot remove an invitation that
  is being accepted at that moment.
- `TRUSTED_PROXIES` accepts address ranges such as `172.20.0.0/16`.

### Changed

- The generated cleanup calls `Ithibati.Web.Gate.expire/1`. It disconnects the LiveViews of
  expired sessions.

## [0.4.0] - 2026-09-24

Requires Ithibati 0.6 and schema version 4.

### Added

- `ACCOUNT_IDENTITY` decides whether an account is a username or an email address. The
  generated `Identity` module answers it, and both schemas ask it for the format.
  Addressed, the invitation is delivered to its address, and an instance that cannot send
  mail does not start.
- The client address comes from `X-Forwarded-For` when a trusted proxy carried it. Rate limits
  count one IPv6 `/64` as one visitor.

### Changed

- Every application ships a mailer.
- The invitation limit is 20 per account per day instead of 10 per hour.
- The rate-limit group `manual_invitation` is renamed to `invite`.
- The Ithibati requirement accepts patch releases instead of one exact version.
- An instance whose first account is not protected by an operator code refuses to start.

### Removed

- The `--with-mail` profile option. Every application includes mail.

## [0.3.0] - 2026-09-20

Requires Ithibati 0.5.0 and schema version 3.

### Added

- Members can create at most 10 invitation links per hour. Mail limits stay independent.

### Changed

- The initial claim uses Ithibati's protected claim API.

## [0.2.0] - 2026-09-20

First tagged release.

### Added

- An Igniter installer that generates a Phoenix application with passkey authentication on
  Ithibati 0.4.0.
- An operator-issued setup code authorizes the first account. Later accounts need an
  invitation.
- Vanilla Tailwind CSS 4, Lucide icons, and English and German screens.
- mise tasks for setup, development, checks and releases, with release start commands.
- `mix ithibati.new`, a Mix archive that selects Phoenix and the starter. It pins the starter
  to its release tag. `--with-mail` adds invitation mail.

### Fixed

- Generation accepts Igniter's prompts by default.
- DaisyUI and Heroicons are unlocked from `mix.lock` after their removal.

[Unreleased]: https://github.com/oliverandrich/ithibati-starter/compare/v0.9.0...HEAD
[0.9.0]: https://github.com/oliverandrich/ithibati-starter/compare/v0.8.1...v0.9.0
[0.8.1]: https://github.com/oliverandrich/ithibati-starter/compare/v0.8.0...v0.8.1
[0.8.0]: https://github.com/oliverandrich/ithibati-starter/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/oliverandrich/ithibati-starter/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/oliverandrich/ithibati-starter/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/oliverandrich/ithibati-starter/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/oliverandrich/ithibati-starter/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/oliverandrich/ithibati-starter/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/oliverandrich/ithibati-starter/releases/tag/v0.2.0
