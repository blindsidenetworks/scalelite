FROM ruby:2.6-alpine AS base

# Set a variable for the install location.
ARG RAILS_ROOT=/usr/src/app
# Set Rails environment.
ENV RAILS_ENV production
ENV BUNDLE_APP_CONFIG="$RAILS_ROOT/.bundle"

# Make the directory and set as working.
RUN mkdir -p $RAILS_ROOT
WORKDIR $RAILS_ROOT

ARG BUILD_PACKAGES="build-base git"
ARG DEV_PACKAGES="yaml-dev zlib-dev"
ARG RUBY_PACKAGES="tzdata"

# Install app dependencies.
RUN apk update \
    && apk upgrade \
    && apk add --update --no-cache $BUILD_PACKAGES $DEV_PACKAGES $RUBY_PACKAGES

COPY Gemfile* ./
COPY Gemfile Gemfile.lock $RAILS_ROOT/

RUN gem install bundler:2.0

RUN bundle config --global frozen 1 \
    && bundle install --deployment --without development:test:assets -j4 --path=vendor/bundle \
    && rm -rf vendor/bundle/ruby/2.6.0/cache/*.gem \
    && find vendor/bundle/ruby/2.6.0/gems/ -name "*.c" -delete \
    && find vendor/bundle/ruby/2.6.0/gems/ -name "*.o" -delete

# Adding project files.
COPY . .

# Remove folders not needed in resulting image
RUN rm -rf tmp/cache spec

############### Build step done ###############

FROM ruby:2.6-alpine

# Set a variable for the install location.
ARG RAILS_ROOT=/usr/src/app
ARG PACKAGES="tzdata bash"
# Set Rails environment.
ENV RAILS_ENV=production
ENV BUNDLE_APP_CONFIG="$RAILS_ROOT/.bundle"

WORKDIR $RAILS_ROOT

RUN apk update \
    && apk upgrade \
    && apk add --update --no-cache $PACKAGES

RUN gem install bundler -v '~> 2.0'

# Adding project files.
COPY --from=base $RAILS_ROOT $RAILS_ROOT

# Expose port 3000.
EXPOSE 3000

# Start the application.
CMD ["bin/start"]
