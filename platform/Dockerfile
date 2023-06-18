# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian instead of
# Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags
#
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian?tab=tags&page=1&name=bullseye-20210902-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: hexpm/elixir:1.13.4-erlang-24.3.3-debian-bullseye-20210902-slim
#
ARG ELIXIR_VERSION=1.14.4
ARG OTP_VERSION=24.3.4.11
ARG DEBIAN_VERSION=bullseye-20230227-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as builder

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git curl gnupg \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN curl -sL https://deb.nodesource.com/setup_18.x  | bash -
RUN apt-get -y install nodejs

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
  mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/appsignal.exs config/
RUN mix deps.compile

COPY priv priv

COPY lib lib

COPY assets assets

# compile assets
RUN mix assets.deploy

# Compile the release
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM docker:20
FROM ${RUNNER_IMAGE}

ARG APP_REVISION="unset"
ENV APP_REVISION=${APP_REVISION}

RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses5 locales \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"

# Add the atlos user
RUN useradd --create-home atlos
RUN chown atlos /app

# set runner ENV
ENV MIX_ENV="prod"

# Copy the utils
COPY utils utils
ENV UTILS_DIR="/app/utils"

# Install packages needed for runtime environment
RUN apt-get update -y && apt-get install -y ffmpeg imagemagick curl python3 python3-pip chromium tmpreaper \
  && apt-get clean && rm -f /var/lib/apt/lists/*_* && python3 -m pip install poetry

USER atlos

# Install and setup Poetry+Python for the `utils/` scripts (archiver, etc.)
RUN cd /app/utils && poetry install --only main --no-interaction --no-ansi

# Only copy the final release from the build stage
COPY --from=builder --chown=atlos:root /app/_build/${MIX_ENV}/rel/platform ./

RUN echo $APP_REVISION > APP_REVISION
RUN echo APP_REVISION=${APP_REVISION}

CMD ["/app/bin/migrate-and-serve"]

ENV ECTO_IPV6 true
ENV ERL_AFLAGS "-proto_dist inet6_tcp"
