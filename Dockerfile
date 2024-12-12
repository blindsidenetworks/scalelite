FROM ubuntu:20.04 AS bbb-playback
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y language-pack-en \
    && update-locale LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8
RUN apt-get update \
    && apt-get install -y software-properties-common curl net-tools nginx
RUN add-apt-repository -y ppa:bigbluebutton/support

RUN apt-get update \
    && apt-get install -y yq
RUN curl -sL https://ubuntu.bigbluebutton.org/repo/bigbluebutton.asc | apt-key add - \
    && echo "deb https://ubuntu.bigbluebutton.org/focal-260 bigbluebutton-focal main" >/etc/apt/sources.list.d/bigbluebutton.list
RUN useradd --system --user-group --home-dir /var/bigbluebutton bigbluebutton
RUN touch /.dockerenv
RUN apt-get update \
    && apt-get download bbb-playback bbb-playback-presentation bbb-playback-podcast bbb-playback-screenshare bbb-playback-video \
    && dpkg -i --force-depends ./*.deb

FROM alpine AS nginx
RUN apk add --no-cache nginx tini gettext \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log
RUN rm /etc/nginx/http.d/default.conf
COPY --from=bbb-playback /var/bigbluebutton/playback /var/bigbluebutton/playback/
COPY nginx/start /etc/nginx/start
COPY nginx/dhparam.pem /etc/nginx/dhparam.pem
COPY nginx/conf.d /etc/nginx/http.d/
COPY nginx/playback /etc/bigbluebutton/nginx/
EXPOSE 80
EXPOSE 443
ENV NGINX_HOSTNAME=localhost
CMD [ "/etc/nginx/start", "-g", "daemon off;" ]

FROM ruby:3.3.6-alpine AS base
RUN apk add --no-cache \
    libpq \
    libxml2 \
    libxslt \
    tini \
    tzdata \
    shared-mime-info
RUN addgroup scalelite --gid 1000 && \
    adduser -u 1000 -h /srv/scalelite -G scalelite -D scalelite
RUN addgroup scalelite-spool --gid 2000 && \
    addgroup scalelite scalelite-spool
ENV RAILS_ENV=production
ENV RAILS_LOG_TO_STDOUT=true
ENV BUNDLE_APP_CONFIG=/srv/scalelite/.bundle
ENV PATH /usr/local/bundle/bin:/usr/local/bundle/gems/bin:$PATH
WORKDIR /srv/scalelite

FROM base as builder
RUN apk add --no-cache \
    build-base \
    libxml2-dev \
    libxslt-dev \
    pkgconf \
    postgresql-dev \
    ruby-dev \
    && ( echo 'install: --no-document' ; echo 'update: --no-document' ) >>/etc/gemrc
USER scalelite:scalelite
COPY --chown=scalelite:scalelite Gemfile* ./
RUN bundle config build.nokogiri --use-system-libraries \
    && bundle install --deployment --without development:test -j4 \
    && rm -rf vendor/bundle/ruby/*/cache \
    && find vendor/bundle/ruby/*/gems/ \( -name '*.c' -o -name '*.o' \) -delete
COPY --chown=scalelite:scalelite . ./
RUN rm -rf nginx

FROM base AS application
USER scalelite:scalelite
COPY --from=builder --chown=scalelite:scalelite /srv/scalelite ./

ARG BUILD_NUMBER
ENV BUILD_NUMBER=${BUILD_NUMBER}

FROM application AS recording-importer
ENV RECORDING_IMPORT_POLL=true
CMD [ "bin/start-recording-importer" ]

FROM application AS poller
CMD [ "bin/start-poller" ]

FROM application AS api
EXPOSE 3000
CMD [ "bin/start" ]
