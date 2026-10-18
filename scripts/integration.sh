#!/usr/bin/env bash
set -euo pipefail

starter_root=$(cd "$(dirname "$0")/.." && pwd)
# The SQLite release check reads the migrated file directly.
if ! command -v sqlite3 >/dev/null; then
  echo "The integration suite needs the sqlite3 command" >&2
  exit 1
fi
fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/ithibati-starter.XXXXXX")
trap 'rm -rf "$fixture_root"' EXIT
unset MIX_ENV
export MIX_TEST_PARTITION="_starter_$$"
export PORT="${PORT:-43129}"
export PGHOST="${PGHOST:-127.0.0.1}"
export PGPORT="${PGPORT:-5432}"
export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"

# Keep archive installation isolated from the developer's installed generators.
archive_source="${MIX_ARCHIVES:-$HOME/.mix/archives}"
mkdir -p "$fixture_root/archives"
for archive in "$archive_source"/*; do
  [[ -e "$archive" ]] || continue
  [[ "$(basename "$archive")" == ithibati_new-* ]] && continue
  ln -s "$archive" "$fixture_root/archives/$(basename "$archive")"
done
export MIX_ARCHIVES="$fixture_root/archives"
mix archive.install hex phx_new 1.8.14 --force
mix archive.install hex igniter_new 0.5.34 --force
(cd "$starter_root/installer" && mix archive.build -o "$fixture_root/ithibati_new.ez")
mix archive.install "$fixture_root/ithibati_new.ez" --force

# One profile. Beans and the license are the variations; the second application varies both.
# The holder is named, because a CI runner has no git user.name to fall back to.
source_url="https://example.com/starter_nobeans"
for profile in beans nobeans; do
  app="starter_${profile}"
  target="$fixture_root/$app"
  options=(--yes --copyright "Integration Suite")
  if [[ "$profile" == nobeans ]]; then
    options+=(--without-beans --license agpl --source-url "$source_url")
  fi

  (cd "$fixture_root" && mix ithibati.new "$target" --starter "ithibati_starter@path:$starter_root" "${options[@]}")
  (
    cd "$target"
    mise trust
    mise install
    mise run check
    mise run setup
    dev_setup_output=$(PHX_SERVER=true mise run setup-code)
    dev_setup_code_lines=$(printf '%s\n' "$dev_setup_output" | grep -Ec '^Initial setup code: [A-Za-z0-9_-]{43}$' || true)
    if [[ "$dev_setup_code_lines" != 1 ]]; then
      echo "Development setup command did not print exactly one setup code" >&2
      exit 1
    fi
    # The second run must preserve the generated sources and any later user edits.
    mix ithibati_starter.install --dry-run "${options[@]}"
    # Every application ships the mailer and decides the identifier at runtime.
    test -e "lib/$app/mailer.ex"
    test -e "lib/$app/identity.ex"
    test -e "test/${app}_web/invitation_delivery_test.exs"
    if [[ "$profile" == nobeans ]]; then
      test ! -e .beans.yml
      grep -q "GNU AFFERO GENERAL PUBLIC LICENSE" LICENSE
    else
      grep -q "Copyright (c) [0-9]* Integration Suite" LICENSE
    fi
    mise release
    release="$target/_build/prod/rel/$app"
    for command in server migrate setup-code; do
      if [[ ! -x "$release/bin/$command" ]]; then
        echo "Missing executable release command: $release/bin/$command" >&2
        exit 1
      fi
    done
    (
      database="${app}_release_$$"
      manual="${app}_manual_$$"
      migrate_variable="$(printf '%s' "$app" | tr '[:lower:]' '[:upper:]')_MIGRATE_ON_START"
      database_variable="$(printf '%s' "$app" | tr '[:lower:]' '[:upper:]')_DATABASE"
      server_pid=""
      createdb "$database"
      createdb "$manual"
      stop_server() {
        if [[ -n "$server_pid" ]]; then
          kill "$server_pid" 2>/dev/null || true
          wait "$server_pid" 2>/dev/null || true
          server_pid=""
        fi
      }
      cleanup_release() {
        stop_server
        dropdb "$database"
        dropdb "$manual"
      }
      trap cleanup_release EXIT
      server_url=$(elixir -e '
        encode = &URI.encode(&1, fn c -> URI.char_unreserved?(c) end)
        user = encode.(System.fetch_env!("PGUSER"))
        password = encode.(System.fetch_env!("PGPASSWORD"))
        IO.write("ecto://#{user}:#{password}@#{System.fetch_env!("PGHOST")}:#{System.fetch_env!("PGPORT")}")
      ')
      use_database() {
        export PGDATABASE="$1" DATABASE_URL="$server_url/$1"
      }
      # The operator command must work in the unpacked release without putting its
      # code in the integration log. Application startup may also print log lines.
      issue_setup_code() {
        setup_output=$(PHX_SERVER=true "$release/bin/setup-code")
        setup_code_lines=$(printf '%s\n' "$setup_output" | grep -Ec '^Initial setup code: [A-Za-z0-9_-]{43}$' || true)
        if [[ "$setup_code_lines" != 1 ]]; then
          echo "Release setup command did not print exactly one setup code" >&2
          exit 1
        fi
      }
      migrated() {
        [[ "$(psql -tAc "select to_regclass('public.schema_migrations') is not null")" == t ]]
      }
      # Run from outside the release directory to verify the launchers resolve it themselves.
      start_server() {
        "$release/bin/server" >"$target/release.log" 2>&1 &
        server_pid=$!
        if ! curl --fail --silent --show-error --retry 30 --retry-connrefused --retry-delay 1 \
          --max-time 2 -H 'x-forwarded-proto: https' \
          "http://localhost:$PORT/health" | grep -F '"status":"ok"'; then
          cat "$target/release.log" >&2
          exit 1
        fi
      }
      SECRET_KEY_BASE=$(elixir -e 'IO.write(Base.encode64(:crypto.strong_rand_bytes(64)))')
      export SECRET_KEY_BASE
      export PHX_HOST=localhost
      # Mail is opt-in, and an instance that addresses its accounts needs it before it will
      # start. This smoke test never sends anything and must not inherit real credentials.
      export ACCOUNT_IDENTITY=email MAIL_ENABLED=true
      export SMTP_HOST=localhost SMTP_PORT=9
      export SMTP_USERNAME=smoke SMTP_PASSWORD=smoke MAIL_FROM=smoke@example.invalid
      cd "$fixture_root"

      # One release serves both databases. PostgreSQL first, chosen explicitly.
      export "$database_variable=postgres"

      # By default every start migrates, so the documented first step finds an empty database.
      use_database "$database"
      issue_setup_code
      if ! migrated; then
        echo "Release did not migrate its database on start" >&2
        exit 1
      fi
      start_server
      # An AGPL application links its source from the sign-in page; an MIT one names none.
      login=$(curl --fail --silent --show-error --location -H 'x-forwarded-proto: https' "http://localhost:$PORT/login")
      if [[ "$profile" == nobeans ]] && ! grep -qF "href=\"$source_url\"" <<<"$login"; then
        echo "The AGPL release does not link its source code" >&2
        exit 1
      elif [[ "$profile" == beans ]] && grep -qF 'target="_blank" rel="noopener noreferrer"' <<<"$login"; then
        echo "The MIT release links a source it was not given" >&2
        exit 1
      fi
      # Nothing is left to apply, so the explicit command is a no-op.
      "$release/bin/migrate"
      stop_server

      # The opt-out leaves the database to the operator.
      use_database "$manual"
      export "$migrate_variable=false"
      start_server
      if migrated; then
        echo "Release migrated although $migrate_variable=false" >&2
        exit 1
      fi
      stop_server
      "$release/bin/migrate"
      "$release/bin/migrate"
      issue_setup_code
      start_server
      stop_server

      # SQLite is the default. The file lives outside the release, in a directory that exists.
      unset "$database_variable" "$migrate_variable" DATABASE_URL PGDATABASE
      sqlite_dir=$(mktemp -d "$fixture_root/sqlite.XXXXXX")
      export DATABASE_PATH="$sqlite_dir/$app.db"
      issue_setup_code
      applied=$(sqlite3 "$DATABASE_PATH" "select count(*) from schema_migrations" || echo 0)
      if [[ "$applied" == 0 ]]; then
        echo "Release did not migrate its SQLite database on start" >&2
        exit 1
      fi
      start_server
      "$release/bin/migrate"
    )
  )
done
