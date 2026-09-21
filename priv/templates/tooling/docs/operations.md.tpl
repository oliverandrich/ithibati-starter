# Operations

`GET /health` is a public liveness endpoint returning `{"status":"ok"}`. It does
not query the database, set cookies, expose configuration or require authentication.
It proves the HTTP application can answer, not that every dependency is ready.

Build with the project's pinned Elixir/OTP versions on a system compatible with
the deployment target:

```sh
mise run release
```

The release is in `_build/prod/rel/__APP__`. Set `DATABASE_URL`, `SECRET_KEY_BASE`,
`PHX_HOST` and `PORT` for the deployment, `TRUSTED_PROXIES` when a reverse proxy
runs on another host, and `ACCOUNT_IDENTITY` with the mail variables when accounts
are addressed rather than named.

| Variable | What it decides |
| --- | --- |
| `ACCOUNT_IDENTITY` | `username` (the default) or `email`; anything else stops the boot. `email` requires the mail settings below |
| `MAIL_ENABLED` | `true` to deliver invitations; required by `ACCOUNT_IDENTITY=email` |
| `MAIL_FROM` | The address invitations come from |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD` | Submission server; the port defaults to 587 |

## Naming or addressing accounts

An account is called one of two things here, and the instance chooses which before
anybody registers.

By default it is a username, and an invitation is a link whoever made it passes on
however they like. Nothing is sent and no mail is configured.

`ACCOUNT_IDENTITY=email` makes it an address instead. The invitation is then addressed
to that address and delivered to it, which is also what proves the address belongs to
whoever answers. That requires `MAIL_ENABLED=true` and the `SMTP_*` variables beside it.
Submission is authenticated and the server's certificate is verified; port 465 is taken
as implicit TLS and anything else as STARTTLS. An instance that asks for addresses
without being able to send any refuses to start and says so.

Choose once, before the first account. Turning an instance that already has accounts
from names to addresses would leave every identifier it holds failing the new format.

## Migrating and starting

Run migration once as an explicit deploy step, issue the first-account setup code
on the server, then start the application:

```sh
bin/migrate
bin/setup-code
bin/server
```

The setup command prints a random code to your terminal; capture it there, not in
service logs or a deployment artifact. Ithibati stores only its digest in the
version 3 setup-code table. Open `https://YOUR_HOST/setup`, enter the code,
enter the identifier this instance asks for, and register a passkey.
The authorization in that browser session lasts ten minutes; re-enter the code if
it expires. A successful claim consumes the code in the account transaction and
closes `/setup`. A server started before a code is issued stays locked for claims.
To replace a lost or exposed code before claiming the instance, run the same command
again. The previous code and sessions authorized by it stop working. On a shared
server, keep the command output visible only to the operator.

The usual deployment is a release behind a reverse proxy on the same host. Every
request then arrives from one socket, so authentication budgets would be shared by
everybody behind it. `__MODULE__Web.ClientIp` takes the visitor's address from
`X-Forwarded-For` instead, and believes that header only on a connection from the
loopback or from an address named in `TRUSTED_PROXIES`, comma separated and one
address per entry rather than a range. A name that is not an address stops the boot
rather than being dropped quietly, so an instance exposed directly still counts the
address it actually sees.

The application refuses to start unless `config :ithibati, initial_claim: :operator_code`
is set. An unprotected claim would hand the instance to the first stranger who finds the
host, so this is a refusal to boot rather than a setup page nobody can satisfy.

The migration command starts the repo without the HTTP server. It is safe to run
again when all migrations are already applied. It does not create the database.
Provide a database and take backups through your deployment's normal workflow.
The application does not migrate automatically during boot.

## Authentication maintenance

Arrange a recurring job on the host, for example daily, to run this against the
already-running release:

```sh
bin/__APP__ rpc '__MODULE__.AuthCleanup.run()'
```

The command reports counts of expired sessions, abandoned challenges and expired,
unaccepted invitations removed. It is safe to repeat and leaves active credentials,
recovery codes and accepted invitations untouched. In development, run
`mix auth.cleanup` explicitly. The release does not install a scheduler or cron job.

Authentication request limits and manual-link invitations use in-memory counters
on each application node. A restart resets their windows. In a multi-node deployment,
use a trusted reverse proxy or shared limiter for a client-IP budget across nodes.
Making an invitation is limited too, but per signed-in account rather than per
address: 20 in a 24-hour window, configurable with the other budgets. The counter
lives in memory on the node that served the request, so several nodes each keep
their own, and an edge rule keyed by address does not replace one keyed by account.
Use a shared account-keyed limiter if a cluster-wide quota is needed.
See [Authentication](authentication.md#authentication-limits-and-maintenance) for
the default limits and configuration.

For an explicitly reviewed rollback, replace the example version below with the
oldest migration version to undo (the boundary version is also rolled back):

```sh
bin/__APP__ eval '__MODULE__.Release.rollback(__MODULE__.Repo, 20260918000000)'
```

No deployment service, container image or job scheduler is imposed by the starter.
