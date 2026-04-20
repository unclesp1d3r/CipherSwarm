# syntax=docker/dockerfile:1
# check=error=true

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.4.5
FROM ruby:$RUBY_VERSION-alpine AS base

# Rails app lives here
WORKDIR /rails

# Update gems and bundler
RUN gem update --system --no-document && \
    gem install -N bundler

# Install base packages
RUN apk add --no-cache curl jemalloc postgresql-client tzdata vips

# Set production environment
ENV BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    RAILS_ENV="production"


# Throw-away build stages to reduce size of final image
FROM base AS prebuild

# Install packages needed to build gems and node modules
RUN apk add --no-cache bash build-base gyp git libffi-dev postgresql-dev pkgconfig python3 yaml-dev


FROM prebuild AS node

# Install Bun directly (standalone JavaScript runtime)
ARG BUN_VERSION=1.3.6
ENV BUN_INSTALL=/usr/local
RUN curl -fsSL https://bun.sh/install | bash -s "bun-v${BUN_VERSION}"
ENV PATH=/usr/local/bin:$PATH

# Install node modules
COPY package.json bun.lockb ./
RUN bun install --frozen-lockfile


FROM prebuild AS build

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 --retry 3 --verbose && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Copy node modules and bun
COPY --from=node /rails/node_modules /rails/node_modules
COPY --from=node /usr/local/bin/bun /usr/local/bin/bun
ENV PATH=/usr/local/bin:$PATH

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile --gemfile && \
    bundle exec bootsnap precompile app/ lib/

# Adjust binfiles to be executable on Linux and set current working directory
RUN chmod +x bin/* && \
    sed -i "s/\r$//g" bin/* && \
    grep -l '#!/usr/bin/env ruby' /rails/bin/* | xargs sed -i '/^#!/aDir.chdir File.expand_path("..", __dir__)'

# Precompile assets using the production JS build script for minification
RUN JSBUNDLING_BUILD_COMMAND="bun run build:production" SECRET_KEY_BASE_DUMMY=1 APPLICATION_HOST=localhost ./bin/rails assets:precompile


# Final stage for app image
FROM base

# Install packages needed for deployment (no vim — keep attack surface small).
RUN apk add --no-cache imagemagick libpq vips wget

# Create an unprivileged user to run the application. The uid/gid are fixed
# so host bind mounts (./storage, tus_uploads, attack_resources) can be chown'd
# predictably by operators on the deployment host.
RUN addgroup -g 1001 -S rails && \
    adduser -S rails -u 1001 -G rails && \
    mkdir -p /rails/tmp /rails/log /rails/storage && \
    chown -R rails:rails /rails

# Copy built artifacts: gems, application. Chown in-copy to avoid a
# second pass that would double the final-image layer size.
COPY --from=build --chown=rails:rails "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build --chown=rails:rails /rails /rails

USER rails

# Deployment options
ENV RUBY_YJIT_ENABLE="1"

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start Puma directly on port 80. Nginx handles HTTP/2, compression,
# and asset caching in production deployments.
EXPOSE 80
ENV PORT=80
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
