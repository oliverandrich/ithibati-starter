# Operations

## Configuration

A release and the container image read the same environment variables.

| Variable | Effect |
| --- | --- |
| `SECRET_KEY_BASE` | Signs and encrypts cookies; create one with `mix phx.gen.secret` |
| `PHX_HOST` | The public host name |
| `PORT` | HTTP port, 4000 by default |
| `__APP_UPCASE___DATABASE` | `sqlite` (default) or `postgres` |
| `DATABASE_PATH` | Absolute path of the SQLite file |
| `DATABASE_URL` | `ecto://USER:PASS@HOST/DATABASE` for PostgreSQL |
| `POOL_SIZE` | Connections; 5 for SQLite, 10 for PostgreSQL |
| `LOG_LEVEL` | `info` (default), `notice`, `warning`, `error`, `critical`, `alert` or `emergency` |
| `LOG_FILE` | Absolute path of a log file instead of stdout |
| `ACCOUNT_IDENTITY` | `username` (default) or `email` |
| `MAIL_ENABLED` | `true` or `false` (default); `true` sends invitations and is required by `ACCOUNT_IDENTITY=email` |
| `MAIL_FROM` | Sender address |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD` | Submission server; port 587 by default |
| `__APP_UPCASE___MIGRATE_ON_START` | `true` (default) or `false` to migrate by hand |
| `TRUSTED_PROXIES` | Proxy addresses or ranges, comma separated |
| `SOURCE_URL` | Absolute URL of this deployment's source code |

A value outside the listed ones stops the boot. `LOG_LEVEL=debug` is refused, because it
logs sessions and query parameters.

## Deployment

A start migrates the database first, including `bin/setup-code` and `bin/grant-admin`.
With `__APP_UPCASE___MIGRATE_ON_START=false`, run `bin/migrate` before `bin/server`. Use that
for migrations that outlast the supervisor's start timeout. Neither path creates a
PostgreSQL database.

### Release

```sh
mise run release
```

The release lands in `_build/prod/rel/__APP__`. Build it on a system compatible with the
target, copy it there, set the variables and run:

```sh
bin/setup-code
bin/server
```

### Container

The `Dockerfile` builds the same release into a Debian image. It runs `bin/server` as
`nobody`, listens on port 4000 and keeps the SQLite file in the volume `/data`:

```sh
docker build -t __APP__ .
docker run -d --name __APP__ --env-file __APP__.env -p 127.0.0.1:4000:4000 \
  -v __APP__-data:/data __APP__
docker exec __APP__ bin/setup-code
```

Behind a proxy on the host, requests reach the container from the Docker bridge gateway.
Name that address in `TRUSTED_PROXIES`, or every visitor shares one rate-limit budget.
Docker collects stdout. A `LOG_FILE` belongs under `/data`, the only directory `nobody` can
write.
Where the image is built, stored and run is up to you. The Elixir and OTP versions in the
`Dockerfile` match `mise.toml`; update both together.

## Claim the instance

Open `https://YOUR_HOST/setup`, enter the code from `bin/setup-code` and register a passkey.
The code is printed once; keep it out of logs. The browser's authorization lasts ten
minutes. Running the command again replaces the code. The first claim closes `/setup` and
makes that account an administrator.

The application refuses to start unless `config :ithibati, initial_claim: :operator_code`
is set. A release that migrates on start also refuses when its accounts contradict
`ACCOUNT_IDENTITY`.

## Databases

SQLite needs no server. Put the file outside the release, for example
`DATABASE_PATH=/var/lib/__APP__/__APP__.db`, in a directory the service user can write.
Back it up while running with `sqlite3 "$DATABASE_PATH" ".backup BACKUP_FILE"`.

PostgreSQL needs `__APP_UPCASE___DATABASE=postgres` and `DATABASE_URL`, and an existing database.

Back up before every update. A new release migrates on start, and replacing it does not undo
that.

## Mail

`ACCOUNT_IDENTITY=email` mails each invitation to its address. It needs `MAIL_ENABLED=true`
and the `SMTP_*` variables; without them the release does not start. Submission is
authenticated and the certificate verified. Port 465 uses implicit TLS, any other port
STARTTLS. Choose the mode before the first account.

## Proxy and HTTPS

Behind a reverse proxy, `__MODULE__Web.ClientIp` reads the visitor's address from
`X-Forwarded-For`. It believes the header only from the loopback or from `TRUSTED_PROXIES`.
An entry is an address or a range such as `172.20.0.0/16`.

Production redirects HTTP to HTTPS and sends HSTS. The proxy terminates TLS and sets
`X-Forwarded-Proto`. That header is trusted from any client, so expose the application only
through the proxy.

## Health

`GET /health` answers `{"status":"ok"}` without a session. It does not query the database.

## Logs

Stdout gets one JSON object per line with `time`, `severity`, `message` and `metadata`.
With `LOG_FILE`, the lines go to that file instead. The release creates its directory. The
file rotates at 10 MB and keeps five gzipped predecessors.
Metadata holds only `request_id`; `__MODULE__.Logging` lists the allowed keys. There is no
access log. A failed request logs its stack trace, which may contain request data. A crash of the
invitation page can log the invitation token.

## Source code

Every layout links to `:source_url` when it is set. An AGPL application sets it in
`config/config.exs`. A deployment of modified code sets `SOURCE_URL` to its own source.

## Administrators

```sh
bin/grant-admin USERNAME
```

In email mode, pass the address. The command exits with 1 when no account matches.

## Auth cleanup

Run this daily against the running release:

```sh
bin/__APP__ rpc '__MODULE__.AuthCleanup.run()'
```

It removes expired sessions, abandoned challenges and expired invitations, and reports the
counts. In development, run `mix auth.cleanup`. Nothing schedules it.

Rate limits live in memory, per node, and reset on restart. [Authentication](authentication.md)
lists them.

## Rollback

Stop the new release, then roll back to and including a migration version:

```sh
bin/__APP__ eval '__MODULE__.Release.rollback(__MODULE__.Repo, 20260918000000)'
```

Start the old release. The new one would migrate again on start.
