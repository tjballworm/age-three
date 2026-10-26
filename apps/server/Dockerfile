# Game server image. Build from apps/server: docker build -t age3-server apps/server
# Stage 1 compiles the code into an Elixir release: one folder with the app, its dependencies and the Erlang VM.
FROM hexpm/elixir:1.18.4-erlang-27.3.4-debian-bookworm-20260610 AS build
ENV MIX_ENV=prod LANG=C.UTF-8
WORKDIR /src
RUN mix local.hex --force && mix local.rebar --force
COPY mix.exs mix.lock* ./
RUN mix deps.get --only prod && mix deps.compile
COPY config config
COPY lib lib
COPY priv priv
RUN mix release

# Stage 2 is only what the release needs to run (the release brings its own Erlang).
FROM debian:bookworm-20260610-slim
RUN apt-get update && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 ca-certificates \
  && rm -rf /var/lib/apt/lists/*
ENV LANG=C.UTF-8
WORKDIR /app
RUN useradd --system --home /app age3
COPY --from=build --chown=age3 /src/_build/prod/rel/age3 ./
USER age3
EXPOSE 8080
CMD ["/app/bin/age3", "start"]
