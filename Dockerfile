ARG RUBY_VERSION=3.2.2
FROM ruby:$RUBY_VERSION

RUN apt-get update -qq \
    && apt-get install -y build-essential libvips bash libffi-dev tzdata postgresql nodejs yarn python3 python3-pip python3-venv && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /usr/share/man

WORKDIR /rails

ENV RAILS_LOG_TO_STDOUT="1" \
RAILS_SERVE_STATIC_FILES="true" \
RAILS_ENV="production" \
BUNDLE_WITHOUT="development"

COPY Gemfile Gemfile.lock ./
RUN bundle install

# Create Python virtual environment and install dependencies
COPY requirements.txt ./
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN bundle exec bootsnap precompile --gemfile app/ lib/

RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

# ENTRYPOINT ["bin/docker-entrypoint"]

EXPOSE 3000
CMD ["./bin/rails", "server"]
