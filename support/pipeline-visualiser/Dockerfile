FROM ruby:3.4.12-alpine3.24@sha256:53dd359160ceeb7963f8e9efea8a2bbbb65278276e024bb0f058261152b5610d

RUN apk update
RUN apk upgrade --available

# Install system-level dependnecies early on so they can be cached effectively for subsequent builds
# build-base: needed to install be able to install BigDecimal extension requried by 'activesupport-duration-human_string' gem
# libxml2-dev: needed to be able to install libxml-ruby gem required by 'activesupport-duration-human_string' gem
# tzdata: needed for setting the correct timezone in the container
RUN apk add build-base libxml2-dev tzdata

WORKDIR /app
ADD Gemfile /app/Gemfile
ADD Gemfile.lock /app/Gemfile.lock

ADD . /app
RUN bundle config set --local system true && \
    bundle config set --local without development && \
    bundle install

RUN ln -s /usr/share/zoneinfo/Europe/London /etc/localtime

EXPOSE 4567

CMD ["ruby", "index.rb"]
