#!/usr/bin/env bash
set -euo pipefail

starter_root=$(cd "$(dirname "$0")/.." && pwd)
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

for profile in auth mail; do
  app="starter_${profile}"
  target="$fixture_root/$app"
  options=(--yes)
  if [[ "$profile" == mail ]]; then
    options=(--yes --with-mail --without-beans)
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
    if [[ "$profile" == mail ]]; then
      test -e "lib/$app/mailer.ex"
      test ! -e .beans.yml
      test -e "test/${app}_web/invitation_mail_test.exs"
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
      server_pid=""
      createdb "$database"
      cleanup_release() {
        if [[ -n "$server_pid" ]]; then
          kill "$server_pid" 2>/dev/null || true
          wait "$server_pid" 2>/dev/null || true
        fi
        dropdb "$database"
      }
      trap cleanup_release EXIT
      export PGDATABASE="$database"
      DATABASE_URL=$(elixir -e '
        encode = &URI.encode(&1, fn c -> URI.char_unreserved?(c) end)
        user = encode.(System.fetch_env!("PGUSER"))
        password = encode.(System.fetch_env!("PGPASSWORD"))
        IO.write("ecto://#{user}:#{password}@#{System.fetch_env!("PGHOST")}:#{System.fetch_env!("PGPORT")}/#{System.fetch_env!("PGDATABASE")}")
      ')
      export DATABASE_URL
      SECRET_KEY_BASE=$(elixir -e 'IO.write(Base.encode64(:crypto.strong_rand_bytes(64)))')
      export SECRET_KEY_BASE
      export PHX_HOST=localhost
      if [[ "$profile" == mail ]]; then
        # Runtime configuration is required even for migrations. This smoke test
        # never sends mail and must not inherit real SMTP credentials.
        export SMTP_HOST=localhost SMTP_PORT=9
        export SMTP_USERNAME=smoke SMTP_PASSWORD=smoke MAIL_FROM=smoke@example.invalid
      fi
      "$release/bin/migrate"
      "$release/bin/migrate"
      # The operator command must work in the unpacked release without putting its
      # code in the integration log. Application startup may also print log lines.
      cd "$fixture_root"
      setup_output=$(PHX_SERVER=true "$release/bin/setup-code")
      setup_code_lines=$(printf '%s\n' "$setup_output" | grep -Ec '^Initial setup code: [A-Za-z0-9_-]{43}$' || true)
      if [[ "$setup_code_lines" != 1 ]]; then
        echo "Release setup command did not print exactly one setup code" >&2
        exit 1
      fi
      # Run from outside the release directory to verify the launchers resolve it themselves.
      "$release/bin/server" >"$target/release.log" 2>&1 &
      server_pid=$!
      if ! curl --fail --silent --show-error --retry 30 --retry-connrefused --retry-delay 1 \
        --max-time 2 -H 'x-forwarded-proto: https' \
        "http://localhost:$PORT/health" | grep -F '"status":"ok"'; then
        cat "$target/release.log" >&2
        exit 1
      fi
    )
  )
done
