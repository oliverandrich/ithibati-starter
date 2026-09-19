#!/bin/sh
set -eu

cd -P -- "$(dirname -- "$0")"
unset PHX_SERVER
exec ./__APP__ eval "__MODULE__.InitialSetup.print_code!()"
