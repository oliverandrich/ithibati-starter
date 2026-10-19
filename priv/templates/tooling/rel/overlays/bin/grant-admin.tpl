#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 USERNAME (the address in email mode)" >&2
  exit 64
fi

# `eval` passes no arguments to the expression, so the identifier travels in the environment.
export GRANT_ADMIN_IDENTIFIER="$1"
cd -P -- "$(dirname -- "$0")"
unset PHX_SERVER
exec ./__APP__ eval "__MODULE__.GrantAdmin.run!()"
