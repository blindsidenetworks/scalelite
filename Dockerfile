FROM alpine:3.11 AS base

RUN apk add --no-cache \
    libstdc++ \
    libxml2 \
    libxslt \
    ruby \
    ruby-bigdecimal \
    ruby-bundler \
    ruby-json \
    tini \
    tzdata \
    && addgroup scalelite \
    && adduser -h /srv/scalelite -G scalelite -D scalelite
WORKDIR /srv/scalelite

FROM base as builder

RUN apk add --no-cache \
    build-base \
    libxml2-dev \
    libxslt-dev \
    pkgconf \
    ruby-dev \
    && ( echo 'install: --no-document' ; echo 'update: --no-document' ) >>/etc/gemrc
USER scalelite:scalelite
COPY --chown=scalelite:scalelite Gemfile* ./
RUN bundle config build.nokogiri --user-system-libraries \
    && bundle install --deployment --without development:test -j4 \
    && rm -rf vendor/bundle/ruby/*/cache \
    && find vendor/bundle/ruby/*/gems/ \( -name '*.c' -o -name '*.o' \) -delete
COPY --chown=scalelite:scalelite . ./

FROM base AS application
USER scalelite:scalelite
ENV RAILS_ENV=production RAILS_LOG_TO_STDOUT=1
COPY --from=builder --chown=scalelite:scalelite /srv/scalelite ./

FROM application AS poller

ENTRYPOINT [ "bin/start-poller" ]

FROM application AS api

EXPOSE 3000
ENTRYPOINT [ "bin/start" ]
