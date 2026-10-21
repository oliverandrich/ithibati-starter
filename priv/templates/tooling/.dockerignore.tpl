# What the image does not need: history, the host's dependencies and builds, tests and local data.
.dockerignore
.git
.github
/cover/
/doc/
/test/
/tmp/
/screenshots/
.elixir_ls
/_build/
/deps/
*.ez
erl_crash.dump
/assets/node_modules/
/priv/static/assets/
/priv/static/cache_manifest.json
# What `mix assets.deploy` wrote on the host. The image digests its own.
/priv/static/**/*.gz
/priv/static/**/*-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f].*
