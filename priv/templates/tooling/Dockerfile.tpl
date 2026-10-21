# The image `mix phx.gen.release --docker` writes, for this application. One image serves SQLite
# and PostgreSQL; __APP_UPCASE___DATABASE chooses when it starts. See docs/operations.md.
#
# The versions match mise.toml. The Debian date is one hexpm/elixir has built for amd64 and arm64.
ARG ELIXIR_VERSION=1.20.4
ARG OTP_VERSION=29.0.6
ARG DEBIAN_VERSION=trixie-20261020-slim

ARG BUILDER_IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="docker.io/debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

# exqlite compiles SQLite when no precompiled NIF fits.
RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential git \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force \
  && mix local.rebar --force

ENV MIX_ENV="prod"

COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# config/runtime.exs is copied last, so changing it rebuilds less.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

RUN mix assets.setup

COPY priv priv
COPY lib lib
RUN mix compile --warnings-as-errors

COPY assets assets
RUN mix assets.deploy

COPY config/runtime.exs config/
COPY rel rel
RUN mix release

FROM ${RUNNER_IMAGE} AS final

RUN apt-get update \
  && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 libsctp1 locales ca-certificates \
  && rm -rf /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
  && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# The SQLite file lives in the volume. A PostgreSQL instance sets __APP_UPCASE___DATABASE=postgres
# and DATABASE_URL instead.
ENV DATABASE_PATH=/data/__APP__.db
RUN mkdir /data && chown nobody /data
VOLUME /data

WORKDIR "/app"
RUN chown nobody /app

ENV MIX_ENV="prod"

COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/__APP__ ./

USER nobody

EXPOSE 4000

# bin/server migrates the database before it serves, unless __APP_UPCASE___MIGRATE_ON_START=false.
CMD ["/app/bin/server"]
