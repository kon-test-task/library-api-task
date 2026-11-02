# Development image. docker-compose.yml bind mounts the project over /rails.
FROM ruby:4.0.9-slim

RUN apt-get update -qq && apt-get install --no-install-recommends -y \
    build-essential curl git libpq-dev libyaml-dev postgresql-client pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /rails

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 3000

# Called through their interpreters, because a Windows checkout can lose the executable bit.
ENTRYPOINT ["bash", "bin/docker-entrypoint"]
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
