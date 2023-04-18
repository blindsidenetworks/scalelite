FROM alpine:3.15 AS alpine

FROM ubuntu:18.04 AS bbb-playback
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y language-pack-en \
    && update-locale LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8
RUN apt-get update \
    && apt-get install -y software-properties-common curl net-tools nginx
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys CC86BB64 \
    && add-apt-repository ppa:rmescandon/yq
RUN apt-get update \
    && apt-get install -y yq
RUN curl -sL https://ubuntu.bigbluebutton.org/repo/bigbluebutton.asc | apt-key add - \
    && echo "deb https://ubuntu.bigbluebutton.org/bionic-240 bigbluebutton-bionic main" >/etc/apt/sources.list.d/bigbluebutton.list
RUN useradd --system --user-group --home-dir /var/bigbluebutton bigbluebutton
RUN touch /.dockerenv
RUN apt-get update \
    && apt-get download bbb-playback bbb-playback-presentation bbb-playback-podcast bbb-playback-screenshare \
    && dpkg -i --force-depends *.deb

FROM alpine AS nginx
RUN apk add --no-cache nginx tini gettext \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log
RUN rm /etc/nginx/http.d/default.conf
COPY --from=bbb-playback /etc/bigbluebutton/nginx /etc/bigbluebutton/nginx/
COPY --from=bbb-playback /var/bigbluebutton/playback /var/bigbluebutton/playback/
COPY nginx/start /etc/nginx/start
COPY nginx/dhparam.pem /etc/nginx/dhparam.pem
COPY nginx/conf.d /etc/nginx/http.d/
RUN ln -s /etc/nginx/http.d/ /etc/nginx/conf.d
EXPOSE 80
EXPOSE 443
ENV NGINX_HOSTNAME=localhost
CMD [ "/etc/nginx/start", "-g", "daemon off;" ]

FROM alpine AS base
RUN apk add --no-cache \
    libpq \
    libxml2 \
    libxslt \
    tini \
    tzdata \
    shared-mime-info
# ruby-start.
# Install Ruby from sources since Scalelite does not use the version shipped with Apline.
ARG RUBY_RELEASE="https://cache.ruby-lang.org/pub/ruby/2.7/ruby-2.7.6.tar.gz"
ARG RUBY="ruby-2.7.6"
RUN apk add --no-cache git make gcc g++ libc-dev pkgconfig \
    libxml2-dev libxslt-dev postgresql-dev coreutils curl wget bash \
    gnupg tar linux-headers bison readline-dev readline zlib-dev \
    zlib yaml-dev autoconf ncurses-dev curl-dev apache2-dev \
    libx11-dev libffi-dev tcl-dev tk-dev
RUN wget --no-verbose -O ruby.tar.gz ${RUBY_RELEASE} && \
    tar -xf ruby.tar.gz && \
    cd /${RUBY} && \
    ac_cv_func_isnan=yes ac_cv_func_isinf=yes \
    ./configure --disable-install-doc && \
    make && \
    make test && \
    make install
RUN cd / && \
    rm ruby.tar.gz && \
    rm -rf ${RUBY_NAME}
# ruby-end.
RUN addgroup scalelite --gid 1000 && \
    adduser -u 1000 -h /srv/scalelite -G scalelite -D scalelite
RUN addgroup scalelite-spool --gid 2000 && \
    addgroup scalelite scalelite-spool
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
ENV RAILS_ENV=production RAILS_LOG_TO_STDOUT=true
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
