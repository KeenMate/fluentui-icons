# Build stage
FROM elixir:1.18-otp-28 AS builder

# Install build dependencies
RUN apt-get update -y && apt-get install -y \
    build-essential \
    git \
    curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set build ENV
ENV MIX_ENV=prod

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Create build directory
WORKDIR /app

# Copy mix files
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mix deps.compile

# Copy config files so esbuild can read its configuration
COPY config config

# Install esbuild and tailwind with proper config available
RUN mix esbuild.install
RUN mix tailwind.install

# Copy assets
COPY assets assets
COPY priv priv

# Compile assets
RUN mix assets.deploy

# Copy source code
COPY lib lib

# Copy release files
COPY rel rel

# Compile application
RUN mix compile

# Build release
RUN mix release

# Runtime stage
FROM debian:bookworm-slim

# Install runtime dependencies (Erlang + system libs)
RUN apt-get update -y && apt-get install -y \
    libstdc++6 \
    openssl \
    libncurses5 \
    locales \
    ca-certificates \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app

# Create non-root user
RUN groupadd -r fluentui && useradd -r -g fluentui fluentui

# Copy the release from builder
COPY --from=builder --chown=fluentui:fluentui /app/_build/prod/rel/fluentui_icons ./

# Switch to non-root user
USER fluentui

# Expose Phoenix port
EXPOSE 4000

# Set environment to enable Phoenix server
ENV PHX_SERVER=true

# Start the release
CMD ["/app/bin/server"]
