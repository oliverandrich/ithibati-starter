[tools]
elixir = "1.20.4-otp-29"
erlang = "29.0.6"
zizmor = "1.30.0"
gitleaks = "8.30.1"
# Playwright runs the browser features on node.
node = "26"

[tasks.setup]
description = "Install dependencies, create the development database and build assets"
depends = ["browser"]
env.MIX_ENV = "dev"
run = "mix setup"

# Playwright drives the browser features with Chrome for Testing, so no installed Chrome is needed.
# The install checks Playwright's cache on every run, so a deleted browser comes back.
[tasks.browser]
description = "Install the Playwright driver and the headless Chrome for the browser features"
depends = ["browser:npm"]
run = "npm exec --prefix assets -- playwright install chromium --only-shell"

[tasks."browser:npm"]
description = "Install the pinned playwright package when the lockfile changed"
sources = ["assets/package-lock.json"]
outputs = ["assets/node_modules/.package-lock.json"]
run = "npm ci --prefix assets --no-audit --no-fund"

[tasks.setup-code]
description = "Issue or replace the first-account setup code"
env.MIX_ENV = "dev"
run = "env -u PHX_SERVER mix run -e '__MODULE__.InitialSetup.print_code!()'"

[tasks.dev]
description = "Start the development server in the foreground"
env.MIX_ENV = "dev"
run = "mix phx.server"

[tasks.debugserver]
description = "Start the development server with IEx"
env.MIX_ENV = "dev"
raw = true
run = "iex -S mix phx.server"

# SQLite is the default and gets every check. PostgreSQL repeats the tests that touch the
# database; the browser features run on SQLite alone.
[tasks.check]
depends = ["browser"]
env.MIX_ENV = "test"
description = "Check workflows, compile, format, lint, security, assets and tests on both databases"
run = [
  "zizmor .github/",
  "gitleaks git --redact --no-banner",
  "gitleaks git --staged --redact --no-banner",
  "gitleaks git --pre-commit --redact --no-banner",
  "__APP_UPCASE___DATABASE=sqlite mix precommit",
  "__APP_UPCASE___DATABASE=postgres mix test",
]

# One command per task, so arguments such as a test path reach `mix test`.
[tasks.test]
depends = ["browser"]
env.MIX_ENV = "test"
description = "Run the tests against SQLite"
run = "__APP_UPCASE___DATABASE=sqlite mix test"

[tasks."test:postgres"]
env.MIX_ENV = "test"
description = "Run the tests against PostgreSQL, without the browser features"
run = "__APP_UPCASE___DATABASE=postgres mix test"

[tasks.format]
run = "mix format"

[tasks.credo]
run = ["mix compile --warnings-as-errors", "mix credo --strict"]

[tasks.audit]
description = "Audit dependency advisories and retired packages separately"
run = ["mix deps.audit", "mix hex.audit"]

[tasks.migrate]
description = "Apply pending development database migrations"
env.MIX_ENV = "dev"
run = "mix ecto.migrate"

[tasks.reset]
description = "Drop and recreate the development database, migrate and seed it"
env.MIX_ENV = "dev"
run = "mix ecto.reset"

[tasks.release]
description = "Build a production release for the current OS and architecture"
env.MIX_ENV = "prod"
run = ["mix deps.get --only prod", "mix assets.setup", "mix compile --warnings-as-errors", "mix assets.deploy", "mix release --overwrite"]
