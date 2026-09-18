#!/usr/bin/env bash
set -euo pipefail

starter_root=$(cd "$(dirname "$0")/.." && pwd)
fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/ithibati-starter.XXXXXX")
trap 'rm -rf "$fixture_root"' EXIT
unset MIX_ENV
export MIX_TEST_PARTITION="_starter_$$"
export PORT="${PORT:-43129}"

# Install pinned generators so changes to their defaults cannot silently change this test.
mix archive.install hex phx_new 1.8.14 --force
mix archive.install hex igniter_new 0.5.34 --force

for profile in auth tooling; do
  app="starter_${profile}"
  target="$fixture_root/$app"
  options=(--yes)
  if [[ "$profile" == tooling ]]; then
    options=(--yes --without-ithibati --without-beans)
  fi

  mix phx.new "$target" --app "$app" --no-mailer --no-install
  (
    cd "$target"
    mix igniter.install "ithibati_starter@path:$starter_root" --only dev --yes "${options[@]}"
    mise trust
    mise install
    mise run check
    # The second run must preserve the generated sources and any later user edits.
    mix ithibati_starter.install --dry-run --yes "${options[@]}"
    if [[ "$profile" == tooling ]]; then
      test ! -e "lib/$app/accounts/user.ex"
      test ! -e .beans.yml
      test ! -e test/features
    fi
    MIX_ENV=prod mix compile --warnings-as-errors
  )
done
