# syntax=docker/dockerfile:1.7
ARG RUBY_VER=3.3.7-slim

FROM ruby:${RUBY_VER}

ENV APP_HOME=/app \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3

WORKDIR $APP_HOME

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      build-essential ca-certificates wget git curl && \
    rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock* ./
RUN gem update --system && gem install bundler && bundle install

COPY . .

RUN useradd -m appuser && \
    mkdir -p /usr/local/bundle && \
    chown -R appuser:appuser $APP_HOME /usr/local/bundle
USER appuser

ENV RACK_ENV=development PORT=8080
EXPOSE 8080

CMD ["bash","-lc","bundle exec rerun -b --pattern '{app,lib,views,public,config}/**/*' -- puma -C config/puma.rb"]
