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
`PHX_HOST` and `PORT` for the deployment. Run migration once as an explicit deploy
step, issue the first-account setup code on the server, then start the application:

```sh
bin/migrate
bin/setup-code
bin/server
```

The setup command prints a random code to your terminal; capture it there, not in
service logs or a deployment artifact. The database stores only its digest. Open
`https://YOUR_HOST/setup`, enter the code, choose a username and register a passkey.
The authorization in that browser session lasts ten minutes; re-enter the code if
it expires. A successful claim consumes the code in the account transaction and
closes `/setup`. A server started before a code is issued stays locked for claims.
To replace a lost or exposed code before claiming the instance, run the same command
again. The previous code and sessions authorized by it stop working. On a shared
server, keep the command output visible only to the operator.

The migration command starts the repo without the HTTP server. It is safe to run
again when all migrations are already applied. It does not create the database.
Provide a database and take backups through your deployment's normal workflow.
The application does not migrate automatically during boot.

For an explicitly reviewed rollback, replace the example version below with the
oldest migration version to undo (the boundary version is also rolled back):

```sh
bin/__APP__ eval '__MODULE__.Release.rollback(__MODULE__.Repo, 20260918000000)'
```

No deployment service, container image or job scheduler is imposed by the starter.
