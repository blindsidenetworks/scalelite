FROM amazonlinux:2.0.20210219.0 AS amazonlinux

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
    && echo "deb https://ubuntu.bigbluebutton.org/bionic-230 bigbluebutton-bionic main" >/etc/apt/sources.list.d/bigbluebutton.list
RUN useradd --system --user-group --home-dir /var/bigbluebutton bigbluebutton
RUN touch /.dockerenv
RUN apt-get update \
    && apt-get download bbb-playback bbb-playback-presentation \
    && dpkg -i --force-depends *.deb

FROM amazonlinux AS amazonlinux-base
ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /sbin/tini
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini.asc /tini.asc
RUN gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 595E85A6B1B4779EA4DAAEC70B588DFF0527A9B7
RUN gpg --batch --verify /tini.asc /sbin/tini
RUN chmod +x /sbin/tini
RUN yum -y install redhat-rpm-config

FROM amazonlinux-base AS nginx
RUN yes | amazon-linux-extras install nginx1
RUN yum -y install gettext
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log
COPY --from=bbb-playback /etc/bigbluebutton/nginx /etc/bigbluebutton/nginx/
COPY --from=bbb-playback /var/bigbluebutton/playback /var/bigbluebutton/playback/
COPY nginx/start /etc/nginx/start
COPY nginx/dhparam.pem /etc/nginx/dhparam.pem
COPY nginx/conf.d /etc/nginx/conf.d/
EXPOSE 80
EXPOSE 443
ENV NGINX_HOSTNAME=localhost
CMD [ "/etc/nginx/start", "-g", "daemon off;" ]

FROM amazonlinux-base AS base
# Install Node.js (needed for yarn)
RUN yum -y install gcc-c++ make
RUN curl -sL https://rpm.nodesource.com/setup_14.x | bash -
RUN yum -y install nodejs
# Install Ruby & Rails
RUN curl -sL -o /etc/yum.repos.d/yarn.repo https://dl.yarnpkg.com/rpm/yarn.repo
RUN amazon-linux-extras enable ruby2.6 \
  && yum -y install git tar gzip yarn shared-mime-info libxslt zlib-devel sqlite-devel mariadb-devel postgresql-devel ruby-devel rubygems-devel rubygem-bundler rubygem-io-console rubygem-irb rubygem-json rubygem-minitest rubygem-net-http-persistent rubygem-net-telnet rubygem-power_assert rubygem-rake rubygem-test-unit rubygem-thor rubygem-xmlrpc rubygem-bigdecimal \
  && gem install rails
RUN yum -y install python3 python3-pip shadow-utils
RUN groupadd scalelite --gid 1000 && \
    useradd -u 1000 -d /srv/scalelite -g scalelite scalelite
RUN groupadd scalelite-spool --gid 2000 && \
    usermod -a -G scalelite-spool scalelite
WORKDIR /srv/scalelite

FROM base as builder
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
